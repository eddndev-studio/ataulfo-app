import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_dot_label.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/bot.dart';
import '../../domain/entities/session_status.dart';

/// Etiqueta legible del canal de un bot. Compartida por el tile (subtítulo) y
/// el buscador del listado (coincidencia por canal).
String channelLabel(BotChannel c) => switch (c) {
  BotChannel.waUnofficial => 'WhatsApp',
  BotChannel.waba => 'WhatsApp Business',
};

/// Fila de un bot dentro de la card del listado (S04): glifo de entidad +
/// nombre + canal, y a la derecha su estado con dos voces distintas:
///
/// - El estado del bot solo habla cuando es excepcional: "Pausado" como pill.
///   Un bot activo no pinta nada — el default en cada fila sería ruido.
/// - La sesión de WhatsApp es ambiental y va quieta ([AppDotLabel]): el color
///   del dot es el semáforo (success = enlazado, danger = sin enlazar porque
///   el bot no puede operar, neutro = transición) y el texto lo verbaliza.
///
/// Toda la fila es tap-target hacia el detalle; el InkWell propio da el
/// ripple (la card contenedora no es tappable).
class BotTile extends StatelessWidget {
  const BotTile({super.key, required this.bot, this.sessionState});

  final Bot bot;

  /// Estado de la sesión de canal, o null si aún no se conoce (fetch en vuelo o
  /// fallido). Null ⇒ el tile no pinta indicador de sesión: no se inventa dato.
  final SessionState? sessionState;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = bot.identifier == null || bot.identifier!.trim().isEmpty
        ? channelLabel(bot.channel)
        : '${channelLabel(bot.channel)} · ${bot.identifier!.trim()}';
    final session = sessionState;
    return InkWell(
      key: Key('bots.tile.${bot.id}'),
      // push (no go): el detalle se apila sobre el listado para que el back
      // físico y la flecha del AppBar vuelvan al shell con la tab Bots activa.
      onTap: () => context.push('/bots/${bot.id}'),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
        child: Row(
          children: <Widget>[
            const AppEntityIcon(icon: Icons.smart_toy_outlined),
            const SizedBox(width: AppTokens.sp4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    bot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTokens.text2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.sp3),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (bot.paused)
                  const AppPill.outline(
                    label: 'Pausado',
                    dot: AppPillDot.paused,
                  ),
                if (bot.paused && session != null)
                  const SizedBox(height: AppTokens.sp1),
                if (session != null) _SessionDot(state: session),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado de la sesión de WhatsApp como indicador quieto. El semáforo vive en
/// el dot: enlazado = success; sin enlazar = danger (el bot no puede operar,
/// es accionable); las transiciones se resumen en un "Conectando…" neutro (el
/// operador no distingue pairing de connecting desde el listado).
class _SessionDot extends StatelessWidget {
  const _SessionDot({required this.state});

  final SessionState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      SessionState.connected => const AppDotLabel(
        color: AppTokens.success,
        label: 'Enlazado',
      ),
      SessionState.disconnected => const AppDotLabel(
        color: AppTokens.danger,
        label: 'Sin enlazar',
      ),
      SessionState.pairing ||
      SessionState.connecting ||
      SessionState.reconnecting => const AppDotLabel(
        color: AppTokens.text2,
        label: 'Conectando…',
      ),
    };
  }
}
