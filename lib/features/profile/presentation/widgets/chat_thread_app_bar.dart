import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/role_privilege.dart';
import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../conversations/domain/entities/conversation.dart';
import '../../../conversations/presentation/widgets/chat_labels_sheet.dart';
import '../../../flow_run/presentation/widgets/flow_run_sheet.dart';
import '../../../messages/presentation/bloc/messages_bloc.dart';
import '../../../monitor/presentation/widgets/bot_state_pill.dart';
import '../../../notes/presentation/widgets/notes_sheet.dart';
import '../../../takeover/presentation/widgets/ai_takeover_sheet.dart';
import '../bloc/profile_bloc.dart';

/// App bar del hilo de mensajes con identidad real: avatar (foto) + nombre del
/// `ProfileBloc` del scope; al tocarlo abre "revisar perfil". Mientras carga (o
/// si falla) cae a un nombre neutro derivado del `chatLid`, sin bloquear el
/// hilo. Implementa `PreferredSizeWidget` para usarse como `Scaffold.appBar`.
class ChatThreadAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatThreadAppBar({
    super.key,
    required this.botId,
    required this.chatLid,
  });

  final String botId;
  final String chatLid;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  /// `kind` del chat para el sheet de etiquetas: del perfil cargado (fuente
  /// autoritativa) o, mientras carga, derivado del chatLid (los grupos llevan
  /// `@g.us`).
  ConversationKind _kindFrom(ProfileState state) {
    final isGroup = state is ProfileLoaded
        ? state.profile.isGroup
        : chatLid.contains('@g.us');
    return isGroup ? ConversationKind.group : ConversationKind.dm;
  }

  /// Abre el menú "⋮" como hoja inferior canónica (la misma superficie que
  /// las acciones sobre un mensaje): cada fila devuelve su acción al cerrarse
  /// la hoja y se despacha con el context del app bar, que sí tiene los
  /// repos/blocs del scope del hilo.
  Future<void> _openActionsSheet(BuildContext context, bool isAdmin) async {
    final action = await showAppBottomSheet<_ThreadAction>(
      context,
      backgroundColor: AppTokens.surface1,
      // Con las entradas ADMIN+ la lista puede superar el tope de una hoja no
      // controlada en pantallas chicas; con scroll controlado la hoja crece al
      // contenido y ninguna acción queda inalcanzable.
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.sp4,
            vertical: AppTokens.sp2,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  key: const Key('thread.run_flow'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_circle_outline),
                  title: const Text('Correr un flujo'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_ThreadAction.runFlow),
                ),
                ListTile(
                  key: const Key('thread.notes'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sticky_note_2_outlined),
                  title: const Text('Notas del chat'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_ThreadAction.notes),
                ),
                if (isAdmin) ...<Widget>[
                  const Divider(height: AppTokens.sp6),
                  ListTile(
                    key: const Key('thread.ai_log'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.psychology_outlined),
                    title: const Text('Razonamiento del bot'),
                    onTap: () =>
                        Navigator.of(sheetContext).pop(_ThreadAction.reasoning),
                  ),
                  ListTile(
                    key: const Key('thread.ai_ledger'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('Bitácora de acciones'),
                    onTap: () =>
                        Navigator.of(sheetContext).pop(_ThreadAction.ledger),
                  ),
                  ListTile(
                    key: const Key('thread.executions'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_outlined),
                    title: const Text('Ejecuciones del chat'),
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_ThreadAction.executions),
                  ),
                  const Divider(height: AppTokens.sp6),
                  // Destructiva e irreversible: al final de la hoja, tras su
                  // propio divisor, y con confirmación antes de despachar.
                  ListTile(
                    key: const Key('thread.clear_history'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_sweep_outlined),
                    title: const Text('Vaciar historial'),
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_ThreadAction.clearHistory),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    // El await cruzó el cierre de la hoja: el app bar sigue montado salvo que
    // el hilo entero se haya ido (back físico durante la hoja).
    if (action == null || !context.mounted) return;
    _onMenuAction(context, action);
  }

  /// Despacha la acción elegida en el menú "⋮": las cotidianas abren un sheet
  /// sobre este chat; las de observabilidad empujan su pantalla dedicada.
  void _onMenuAction(BuildContext context, _ThreadAction action) {
    switch (action) {
      case _ThreadAction.runFlow:
        FlowRunSheet.open(context, botId: botId, chatLid: chatLid);
      case _ThreadAction.notes:
        NotesSheet.open(context, botId: botId, chatLid: chatLid);
      case _ThreadAction.reasoning:
        context.push(
          '/bots/$botId/sessions/${Uri.encodeComponent(chatLid)}/ai-log',
        );
      case _ThreadAction.ledger:
        context.push(
          '/bots/$botId/sessions/${Uri.encodeComponent(chatLid)}/ai-ledger',
        );
      case _ThreadAction.executions:
        context.push(
          '/bots/$botId/sessions/${Uri.encodeComponent(chatLid)}/executions',
        );
      case _ThreadAction.clearHistory:
        _confirmClearHistory(context);
    }
  }

  /// Confirmación explícita del vaciado (destructivo, irreversible): solo el
  /// "Vaciar" del diálogo despacha; cancelar o descartar no toca nada.
  Future<void> _confirmClearHistory(BuildContext context) async {
    final bloc = context.read<MessagesBloc>();
    final confirmed = await showAppConfirmDialog(
      context,
      title: '¿Vaciar historial?',
      message:
          'Se eliminarán los mensajes de esta conversación y la memoria del '
          'bot sobre ella. El contacto y sus etiquetas se conservan. '
          'No se puede deshacer.',
      confirmLabel: 'Vaciar',
      confirmKey: const Key('thread.clear_history.confirm'),
    );
    if (confirmed) {
      bloc.add(const MessagesClearHistoryRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppBar(
      titleSpacing: 0,
      actions: <Widget>[
        // Etiquetas de este chat (internas + WhatsApp; reusa el sheet de la
        // lista de conversaciones). Acción frecuente: queda visible en la barra.
        // Los repos los provee la ruta.
        IconButton(
          key: const Key('thread.labels'),
          tooltip: 'Etiquetas',
          icon: const Icon(Icons.label_outline),
          onPressed: () => ChatLabelsSheet.open(
            context,
            botId: botId,
            chatLid: chatLid,
            kind: _kindFrom(context.read<ProfileBloc>().state),
          ),
        ),
        // El control del bot y el resto de acciones se agrupan tras una sola
        // lectura del rol para no saturar la barra. "Control del bot"
        // (pausar/reanudar) queda visible para ADMIN+ porque leer las etiquetas
        // de silencio exige acceso a la plantilla; correr flujo y notas viven
        // siempre en el menú (operación cotidiana, sin gate); y las pantallas
        // de observabilidad (razonamiento/bitácora/ejecuciones) se agregan al
        // menú solo para ADMIN+ (el backend igual rechaza con 403).
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final isAdmin =
                authState is AuthAuthenticated &&
                isAdminOrAbove(authState.identity.role);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (isAdmin)
                  IconButton(
                    key: const Key('thread.takeover'),
                    tooltip: 'Control del bot',
                    icon: const Icon(Icons.smart_toy_outlined),
                    onPressed: () => AiTakeoverSheet.open(
                      context,
                      botId: botId,
                      chatLid: chatLid,
                    ),
                  ),
                IconButton(
                  key: const Key('thread.more'),
                  tooltip: 'Más acciones',
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _openActionsSheet(context, isAdmin),
                ),
              ],
            );
          },
        ),
      ],
      title: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          // El chatLid es jerga de wire: NUNCA se pinta como nombre. Mientras
          // no hay identidad se comunica la espera; los grupos son detectables
          // por el sufijo del JID aun sin perfil.
          final (String name, String? photo) = switch (state) {
            ProfileLoaded(profile: final p) => (
              p.displayName ?? (p.isGroup ? 'Grupo' : (p.phone ?? 'Chat')),
              p.photoUrl,
            ),
            _ => (chatLid.contains('@g.us') ? 'Grupo' : 'Cargando…', null),
          };
          // El header completo es un botón: el lector de pantalla lo anuncia
          // como control ("Ver perfil") en vez de leer el nombre como texto
          // inerte. ExcludeSemantics evita que el nombre se anuncie dos veces
          // (ya está en el label del Semantics y en el de AppAvatar).
          return Semantics(
            button: true,
            label: name,
            hint: 'Ver perfil',
            child: InkWell(
              onTap: () => context.push(
                '/bots/$botId/sessions/${Uri.encodeComponent(chatLid)}/profile',
              ),
              child: ExcludeSemantics(
                child: Row(
                  children: <Widget>[
                    AppAvatar(
                      name: name,
                      size: 36,
                      imageUrl: photo,
                      colorKey: chatLid,
                    ),
                    const SizedBox(width: AppTokens.sp3),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium,
                          ),
                          // Estado en vivo del bot (Pensando / falló); oculto en
                          // reposo. Lo alimenta el MonitorLiveCubit del scope.
                          const BotStatePill(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Acción seleccionable del menú "⋮" del hilo. Cada valor mapea a un sheet del
/// chat, a una pantalla de observabilidad, o al vaciado del historial (con
/// confirmación previa).
enum _ThreadAction {
  runFlow,
  notes,
  reasoning,
  ledger,
  executions,
  clearHistory,
}
