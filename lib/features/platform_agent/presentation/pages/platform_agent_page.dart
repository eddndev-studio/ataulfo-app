import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_thread_list_sheet.dart';
import '../../domain/entities/pa_conversation.dart';
import '../../domain/failures/pa_failure.dart';
import '../bloc/platform_agent_chat_bloc.dart';
import '../widgets/pa_chat_view.dart';
import '../widgets/pa_conversation_rename_sheet.dart';
import '../widgets/pa_failure_copy.dart';

/// Pestaña del asistente de plataforma: chat conversacional con el operador.
/// Vive como tab del shell (no como overlay), así hereda del Scaffold el
/// resize por teclado y el back estándar. Lee `PlatformAgentChatBloc` del
/// context (provisto arriba del shell) y dispara la carga la primera vez que
/// la tab se abre (init perezoso: solo si el estado sigue en Loading).
class PlatformAgentPage extends StatefulWidget {
  const PlatformAgentPage({
    super.key,
    this.initialDraft = '',
    this.headerLeading,
    this.headerActions = const <Widget>[],
  });

  final String initialDraft;
  final Widget? headerLeading;
  final List<Widget> headerActions;

  @override
  State<PlatformAgentPage> createState() => _PlatformAgentPageState();
}

class _PlatformAgentPageState extends State<PlatformAgentPage> {
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
    if (widget.initialDraft.trim().isNotEmpty) {
      bloc.add(PaChatDraftSeeded(widget.initialDraft));
    }
  }

  void _send(String text) {
    final bloc = context.read<PlatformAgentChatBloc>();
    final s = bloc.state;
    // No despachar con un lote de adjuntos a medio subir: cerraría el turno con
    // un subconjunto y perdería en silencio los que aún suben.
    if (s is PaChatLoaded && (s.sending || s.attaching)) return;
    bloc.add(PaChatMessageSent(text));
  }

  /// Abre el selector de hilos compartido. Tocar un hilo lo activa y cierra el
  /// cajón; el menú por hilo cablea Renombrar (form-sheet) y Eliminar (confirma
  /// antes de borrar) a los eventos del bloc.
  void _showThreads() {
    final bloc = context.read<PlatformAgentChatBloc>();
    final state = bloc.state;
    if (state is! PaChatLoaded) return;
    showAppBottomSheet<void>(
      context,
      builder: (sheetCtx) => AppThreadListSheet(
        keyPrefix: 'pa.history',
        title: 'Conversaciones',
        activeId: state.activeConversation.id,
        items: <AppThreadListItem>[
          for (final c in state.conversations)
            AppThreadListItem(
              id: c.id,
              title: c.title.isNotEmpty ? c.title : 'Nueva conversación',
              subtitle: _relativeThreadDate(c.updatedAt),
            ),
        ],
        onSelect: (id) {
          Navigator.of(sheetCtx).pop();
          bloc.add(PaChatConversationSelected(id));
        },
        onRename: (id) => _renameThread(sheetCtx, id, state.conversations),
        onDelete: (id) => _deleteThread(sheetCtx, id),
      ),
    );
  }

  Future<void> _renameThread(
    BuildContext sheetCtx,
    String id,
    List<PaConversation> conversations,
  ) async {
    final conv = conversations.firstWhere((c) => c.id == id);
    Navigator.of(sheetCtx).pop();
    final newTitle = await PaConversationRenameSheet.open(
      context,
      initial: conv.title,
    );
    if (!mounted) return;
    if (newTitle != null && newTitle.isNotEmpty && newTitle != conv.title) {
      context.read<PlatformAgentChatBloc>().add(
        PaChatConversationRenamed(id, newTitle),
      );
    }
  }

  Future<void> _deleteThread(BuildContext sheetCtx, String id) async {
    final bloc = context.read<PlatformAgentChatBloc>();
    final ok = await showAppConfirmDialog(
      sheetCtx,
      title: 'Eliminar conversación',
      message: 'Se borrará el hilo y sus mensajes. No se puede deshacer.',
      confirmLabel: 'Eliminar',
      confirmKey: const Key('pa.history.delete.confirm'),
    );
    if (!ok) return;
    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
    bloc.add(PaChatConversationDeleted(id));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('pa.page'),
      color: AppTokens.bgBase,
      child: Column(
        children: <Widget>[
          _Header(
            leading: widget.headerLeading,
            actions: widget.headerActions,
            onThreads: _showThreads,
            onNew: () => context.read<PlatformAgentChatBloc>().add(
              const PaChatNewConversationRequested(),
            ),
          ),
          Expanded(
            child: BlocBuilder<PlatformAgentChatBloc, PaChatState>(
              builder: (context, state) => switch (state) {
                PaChatLoading() => const AppLoadingIndicator(),
                PaChatFailed(:final failure) => _FailedView(failure: failure),
                PaChatLoaded() => PaChatView(state: state, onSend: _send),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Header full-bleed de la pestaña: reserva el inset del status bar (como las
/// demás tabs del shell, que van sin AppBar). Marca + acciones de modelo,
/// conversaciones y nuevo hilo.
///
/// Deliberadamente NO es la tarjeta-header gradiente de las secciones: esta
/// tab es un chat (hilo + composer fijos, sin scroll que se lleve el header),
/// así que el chrome compacto tipo app bar — como el del hilo de mensajes —
/// preserva la altura del hilo con el teclado abierto; además sus acciones
/// comunican estado por color (modelo elegido), lenguaje que no lee sobre el
/// gradiente de marca.
class _Header extends StatelessWidget {
  const _Header({
    required this.onThreads,
    required this.onNew,
    required this.leading,
    required this.actions,
  });

  final VoidCallback onThreads;
  final VoidCallback onNew;
  final Widget? leading;
  final List<Widget> actions;

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
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: AppTokens.sp1),
          ],
          const Icon(Icons.auto_awesome, size: 20, color: AppTokens.primary),
          const SizedBox(width: AppTokens.sp2),
          Expanded(
            child: BlocBuilder<PlatformAgentChatBloc, PaChatState>(
              buildWhen: (before, after) =>
                  before is! PaChatLoaded ||
                  after is! PaChatLoaded ||
                  before.activeConversation != after.activeConversation,
              builder: (context, state) {
                final title = state is PaChatLoaded
                    ? state.activeConversation.title.trim()
                    : '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Copiloto',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: AppTokens.text1),
                    ),
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTokens.text2,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          ...actions,
          const _ModelMenu(),
          IconButton(
            key: const Key('pa.history'),
            tooltip: 'Conversaciones',
            icon: const Icon(Icons.history, color: AppTokens.text2),
            onPressed: onThreads,
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

String _relativeThreadDate(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final delta = today.difference(day).inDays;
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  if (delta == 0) return 'Hoy · $hh:$mm';
  if (delta == 1) return 'Ayer · $hh:$mm';
  return '${local.day}/${local.month}/${local.year}';
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

/// Estado de fallo de la carga inicial: copy por tipo de fallo sobre el estado
/// de error canónico del kit, con reintento que redispara la carga.
class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final PaFailure failure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: AppErrorState(
          message: platformAgentFailureCopy(failure),
          onRetry: () =>
              context.read<PlatformAgentChatBloc>().add(const PaChatStarted()),
        ),
      ),
    );
  }
}
