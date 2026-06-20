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
  });

  final List<PaConversation> conversations;
  final String activeId;
  final ValueChanged<String> onSelect;

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
          onTap: () => onSelect(c.id),
        );
      },
    );
  }
}

class _ChatView extends StatelessWidget {
  const _ChatView({required this.state, required this.onSend});

  final PaChatLoaded state;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final s = state;
    return Column(
      children: <Widget>[
        Expanded(
          child: (s.messages.isEmpty && !s.sending)
              ? const _EmptyHint()
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(AppTokens.sp3),
                  itemCount: s.messages.length + (s.sending ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (s.sending && i == 0) {
                      return _LiveProgress(label: s.liveProgress);
                    }
                    final idx =
                        s.messages.length - 1 - (i - (s.sending ? 1 : 0));
                    return PaMessageTile(message: s.messages[idx]);
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

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

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
          ],
        ),
      ),
    );
  }
}
