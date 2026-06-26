import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/role_privilege.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../conversations/domain/entities/conversation.dart';
import '../../../conversations/presentation/widgets/chat_labels_sheet.dart';
import '../../../flow_run/presentation/widgets/flow_run_sheet.dart';
import '../../../monitor/presentation/widgets/bot_state_pill.dart';
import '../../../notes/presentation/widgets/notes_sheet.dart';
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppBar(
      titleSpacing: 0,
      actions: <Widget>[
        // Correr un flujo sobre este chat (S11). El `FlowRunRepository` lo
        // provee la ruta. Acción operativa del monitor (WORKER+ en el backend).
        IconButton(
          key: const Key('thread.run_flow'),
          tooltip: 'Correr un flujo',
          icon: const Icon(Icons.play_circle_outline),
          onPressed: () =>
              FlowRunSheet.open(context, botId: botId, chatLid: chatLid),
        ),
        // Etiquetas de este chat (internas + WhatsApp; reusa el sheet de la
        // lista de conversaciones). Los repos los provee la ruta.
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
        // Cuaderno de notas del chat (S14): el mismo que lee/escribe el
        // agente IA (save_note/read_notes). El `NotesRepository` lo provee
        // la ruta.
        IconButton(
          key: const Key('thread.notes'),
          tooltip: 'Notas del chat',
          icon: const Icon(Icons.sticky_note_2_outlined),
          onPressed: () =>
              NotesSheet.open(context, botId: botId, chatLid: chatLid),
        ),
        // Observabilidad del bot (S12): qué pensó, qué tools usó y qué
        // costó cada corrida del motor en ESTE chat. Solo ADMIN+ (el
        // backend igual rechaza con 403; ocultarlo evita el botón roto).
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            if (authState is! AuthAuthenticated ||
                !isAdminOrAbove(authState.identity.role)) {
              return const SizedBox.shrink();
            }
            return IconButton(
              key: const Key('thread.ai_log'),
              tooltip: 'Razonamiento del bot',
              icon: const Icon(Icons.psychology_outlined),
              onPressed: () => context.push(
                '/bots/$botId/sessions/${Uri.encodeComponent(chatLid)}/ai-log',
              ),
            );
          },
        ),
        // Historial de ejecuciones de flujo de ESTE chat (S11): qué corrió y
        // por qué falló. Solo ADMIN+ (el backend igual rechaza con 403).
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            if (authState is! AuthAuthenticated ||
                !isAdminOrAbove(authState.identity.role)) {
              return const SizedBox.shrink();
            }
            return IconButton(
              key: const Key('thread.executions'),
              tooltip: 'Ejecuciones del chat',
              icon: const Icon(Icons.history_outlined),
              onPressed: () => context.push(
                '/bots/$botId/sessions/${Uri.encodeComponent(chatLid)}/executions',
              ),
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
                    AppAvatar(name: name, size: 36, imageUrl: photo),
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
