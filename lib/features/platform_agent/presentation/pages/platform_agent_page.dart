import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_chat_composer.dart';
import '../../../../core/design/widgets/typing_bubble.dart';
import '../../domain/entities/pa_conversation.dart';
import '../../domain/failures/pa_failure.dart';
import '../bloc/platform_agent_chat_bloc.dart';
import '../widgets/pa_failure_copy.dart';
import '../widgets/pa_message_tile.dart';

/// Pestaña del asistente de plataforma: chat conversacional con el operador.
/// Vive como tab del shell (no como overlay), así hereda del Scaffold el
/// resize por teclado y el back estándar. Lee `PlatformAgentChatBloc` del
/// context (provisto arriba del shell) y dispara la carga la primera vez que
/// la tab se abre (init perezoso: solo si el estado sigue en Loading).
class PlatformAgentPage extends StatefulWidget {
  const PlatformAgentPage({super.key});

  @override
  State<PlatformAgentPage> createState() => _PlatformAgentPageState();
}

class _PlatformAgentPageState extends State<PlatformAgentPage> {
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    // Carga perezosa: la tab solo se construye cuando se abre. Si el bloc
    // sigue en su estado inicial, arrancamos; si ya cargó (re-entrada a la
    // tab), conservamos el hilo vivo.
    final bloc = context.read<PlatformAgentChatBloc>();
    if (bloc.state is PaChatLoading) {
      bloc.add(const PaChatStarted());
    }
  }

  void _send(String text) {
    final bloc = context.read<PlatformAgentChatBloc>();
    final s = bloc.state;
    if (s is PaChatLoaded && s.sending) return;
    bloc.add(PaChatMessageSent(text));
  }

  void _select(String id) {
    context.read<PlatformAgentChatBloc>().add(PaChatConversationSelected(id));
    setState(() => _showHistory = false);
  }

  void _rename(String id, String title) {
    context.read<PlatformAgentChatBloc>().add(
      PaChatConversationRenamed(id, title),
    );
  }

  void _delete(String id) {
    context.read<PlatformAgentChatBloc>().add(PaChatConversationDeleted(id));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('pa.page'),
      color: AppTokens.bgBase,
      child: Column(
        children: <Widget>[
          _Header(
            showHistory: _showHistory,
            onToggleHistory: () => setState(() => _showHistory = !_showHistory),
            onNew: () => context.read<PlatformAgentChatBloc>().add(
              const PaChatNewConversationRequested(),
            ),
          ),
          Expanded(
            child: BlocBuilder<PlatformAgentChatBloc, PaChatState>(
              builder: (context, state) => switch (state) {
                PaChatLoading() => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTokens.primary,
                    ),
                  ),
                ),
                PaChatFailed(:final failure) => _FailedView(failure: failure),
                PaChatLoaded() =>
                  _showHistory
                      ? _HistoryList(
                          conversations: state.conversations,
                          activeId: state.activeConversation.id,
                          onSelect: _select,
                          onRename: _rename,
                          onDelete: _delete,
                        )
                      : _ChatView(state: state, onSend: _send),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Header full-bleed de la pestaña: reserva el inset del status bar (como las
/// demás tabs del shell, que van sin AppBar). Marca mango + acciones de
/// historial y nuevo hilo.
class _Header extends StatelessWidget {
  const _Header({
    required this.showHistory,
    required this.onToggleHistory,
    required this.onNew,
  });

  final bool showHistory;
  final VoidCallback onToggleHistory;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp3,
        topInset + AppTokens.sp2,
        AppTokens.sp1,
        AppTokens.sp2,
      ),
      decoration: const BoxDecoration(
        color: AppTokens.surface1,
        border: Border(bottom: BorderSide(color: AppTokens.divider)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.auto_awesome, size: 20, color: AppTokens.primary),
          const SizedBox(width: AppTokens.sp2),
          Expanded(
            child: Text(
              'Asistente',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppTokens.text1),
            ),
          ),
          const _ModelMenu(),
          IconButton(
            key: const Key('pa.history'),
            tooltip: 'Conversaciones',
            icon: Icon(
              Icons.history,
              color: showHistory ? AppTokens.primary : AppTokens.text2,
            ),
            onPressed: onToggleHistory,
          ),
          IconButton(
            key: const Key('pa.new_conversation'),
            tooltip: 'Nueva conversación',
            icon: const Icon(
              Icons.add_comment_outlined,
              color: AppTokens.text2,
            ),
            onPressed: onNew,
          ),
        ],
      ),
    );
  }
}

/// Menú de modelo del asistente. Solo aparece cuando el server expone la
/// allowlist (estado Loaded con modelos); elegir "Por defecto" regresa al
/// modelo de la plataforma (el turno viaja sin `model`). La elección vive en
/// el estado del bloc — por sesión de pantalla, no se persiste.
class _ModelMenu extends StatelessWidget {
  const _ModelMenu();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlatformAgentChatBloc, PaChatState>(
      builder: (context, state) {
        if (state is! PaChatLoaded || state.models.isEmpty) {
          return const SizedBox.shrink();
        }
        final selected = state.selectedModelId;
        return PopupMenuButton<String>(
          key: const Key('pa.model.button'),
          tooltip: 'Modelo del asistente',
          icon: Icon(
            Icons.psychology_outlined,
            color: selected.isEmpty ? AppTokens.text2 : AppTokens.primary,
          ),
          onSelected: (id) => context.read<PlatformAgentChatBloc>().add(
            PaChatModelSelected(id),
          ),
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            CheckedPopupMenuItem<String>(
              key: const Key('pa.model.option.default'),
              value: '',
              checked: selected.isEmpty,
              child: const Text('Por defecto'),
            ),
            for (final m in state.models)
              CheckedPopupMenuItem<String>(
                key: Key('pa.model.option.${m.id}'),
                value: m.id,
                checked: selected == m.id,
                child: Text(
                  m.id == state.defaultModelId
                      ? '${m.label} (por defecto)'
                      : m.label,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final PaFailure failure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              platformAgentFailureCopy(failure),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.sp3),
            KeyedSubtree(
              key: const Key('pa.retry'),
              child: AppButton.tonal(
                label: 'Reintentar',
                onPressed: () => context.read<PlatformAgentChatBloc>().add(
                  const PaChatStarted(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.conversations,
    required this.activeId,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
  });

  final List<PaConversation> conversations;
  final String activeId;
  final ValueChanged<String> onSelect;
  final void Function(String id, String title) onRename;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('pa.history.list'),
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp2),
      itemCount: conversations.length,
      itemBuilder: (context, i) {
        final c = conversations[i];
        final active = c.id == activeId;
        return ListTile(
          key: Key('pa.history.item.${c.id}'),
          leading: Icon(
            Icons.chat_bubble_outline,
            color: active ? AppTokens.primary : AppTokens.text2,
          ),
          title: Text(
            c.title.isNotEmpty ? c.title : 'Conversación',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: active ? AppTokens.primary : AppTokens.text1,
            ),
          ),
          trailing: PopupMenuButton<String>(
            key: Key('pa.history.menu.${c.id}'),
            icon: const Icon(Icons.more_vert, color: AppTokens.text2),
            onSelected: (action) {
              if (action == 'rename') {
                _promptRename(context, c);
              } else if (action == 'delete') {
                _confirmDelete(context, c);
              }
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'rename', child: Text('Renombrar')),
              PopupMenuItem<String>(value: 'delete', child: Text('Eliminar')),
            ],
          ),
          onTap: () => onSelect(c.id),
        );
      },
    );
  }

  Future<void> _promptRename(BuildContext context, PaConversation c) async {
    final ctrl = TextEditingController(text: c.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Renombrar conversación'),
        content: TextField(
          key: const Key('pa.history.rename.field'),
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('pa.history.rename.confirm'),
            onPressed: () => Navigator.of(dialogCtx).pop(ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newTitle != null && newTitle.isNotEmpty && newTitle != c.title) {
      onRename(c.id, newTitle);
    }
  }

  Future<void> _confirmDelete(BuildContext context, PaConversation c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Eliminar conversación'),
        content: const Text(
          'Se borrará el hilo y sus mensajes. No se puede deshacer.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('pa.history.delete.confirm'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok ?? false) onDelete(c.id);
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({required this.state, required this.onSend});

  final PaChatLoaded state;
  final ValueChanged<String> onSend;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  /// Controller compartido: las acciones rápidas PREFIJAN el texto del composer
  /// (el operador lo edita antes de enviar) en vez de auto-enviar.
  final TextEditingController _composer = TextEditingController();

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  void _prefill(String text) {
    _composer.text = text;
    _composer.selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final onSend = widget.onSend;
    return Column(
      children: <Widget>[
        Expanded(
          child: (s.messages.isEmpty && !s.sending)
              ? _EmptyHint(onQuickAction: _prefill)
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(AppTokens.sp3),
                  itemCount:
                      s.messages.length +
                      (s.sending ? 1 : 0) +
                      (s.nextCursor.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (s.sending && i == 0) {
                      return _LiveProgress(label: s.liveProgress);
                    }
                    // El cargar-más vive en el tope visual (último índice del
                    // reverse), por encima del mensaje más viejo.
                    final base = s.messages.length + (s.sending ? 1 : 0);
                    if (s.nextCursor.isNotEmpty && i == base) {
                      return _LoadMoreButton(
                        loading: s.loadingMore,
                        onTap: () => context.read<PlatformAgentChatBloc>().add(
                          const PaChatLoadMore(),
                        ),
                      );
                    }
                    final idx =
                        s.messages.length - 1 - (i - (s.sending ? 1 : 0));
                    return PaMessageTile(
                      message: s.messages[idx],
                      onConfirm: s.sending
                          ? null
                          : () => onSend('Sí, confírmalo y procede.'),
                    );
                  },
                ),
        ),
        if (s.sendFailure != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
            child: Text(
              platformAgentFailureCopy(s.sendFailure!),
              key: const Key('pa.send_failure'),
              style: const TextStyle(color: AppTokens.danger),
            ),
          ),
        AppChatComposer(
          controller: _composer,
          fieldKey: const Key('pa.composer.field'),
          sendKey: const Key('pa.composer.send'),
          hint: 'Pídele algo a tu asistente…',
          enabled: !s.sending,
          onSend: onSend,
        ),
      ],
    );
  }
}

/// Indicador en vivo del turno: typing + la etiqueta de progreso del SSE.
class _LiveProgress extends StatelessWidget {
  const _LiveProgress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const TypingBubble(key: Key('pa.typing')),
        if (label.isNotEmpty) ...<Widget>[
          const SizedBox(width: AppTokens.sp2),
          Flexible(
            child: Text(
              label,
              key: const Key('pa.live_progress'),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppTokens.text2),
            ),
          ),
        ],
      ],
    );
  }
}

/// Una acción rápida del estado vacío: etiqueta visible + texto con el que
/// prefija el composer (puede diferir, p.ej. dejar el bot/flujo a completar).
class _QuickAction {
  const _QuickAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.prefill,
  });

  final String id;
  final String label;
  final IconData icon;
  final String prefill;
}

const List<_QuickAction> _quickActions = <_QuickAction>[
  _QuickAction(
    id: 'bots',
    label: '¿Cuántos bots tengo?',
    icon: Icons.smart_toy_outlined,
    prefill: '¿Cuántos bots tengo y cómo se llaman?',
  ),
  _QuickAction(
    id: 'pause',
    label: 'Pausar un bot',
    icon: Icons.pause_circle_outline,
    prefill: 'Pausa el bot ',
  ),
  _QuickAction(
    id: 'audit',
    label: 'Auditar un flujo',
    icon: Icons.fact_check_outlined,
    prefill: 'Audita el flujo ',
  ),
  _QuickAction(
    id: 'clone',
    label: 'Duplicar un flujo',
    icon: Icons.copy_all_outlined,
    prefill: 'Duplica el flujo ',
  ),
];

/// Botón "cargar mensajes anteriores" al tope del hilo; spinner mientras viaja.
class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppTokens.sp2),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
                ),
              )
            : TextButton(
                key: const Key('pa.load_more'),
                onPressed: onTap,
                child: const Text('Cargar mensajes anteriores'),
              ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.onQuickAction});

  /// Prefija el composer con el arranque de una acción rápida.
  final ValueChanged<String> onQuickAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('pa.empty_hint'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.auto_awesome, size: 48, color: AppTokens.primary),
            const SizedBox(height: AppTokens.sp3),
            Text(
              'Tu asistente de plataforma',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(color: AppTokens.text1),
            ),
            const SizedBox(height: AppTokens.sp2),
            Text(
              'Pídele que liste tus bots, ajuste una plantilla, cree o borre '
              'flujos, o apague la IA de un bot. Te pedirá confirmación cuando '
              'un cambio afecte a varios bots.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppTokens.sp2,
              runSpacing: AppTokens.sp2,
              children: <Widget>[
                for (final a in _quickActions)
                  ActionChip(
                    key: Key('pa.quick_action.${a.id}'),
                    avatar: Icon(a.icon, size: 16, color: AppTokens.primary),
                    label: Text(a.label),
                    onPressed: () => onQuickAction(a.prefill),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
