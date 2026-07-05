import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';
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

/// Card tappable de un bot en el listado (S04). Glifo de entidad + nombre +
/// canal, y a la derecha el estado del bot (Activo/Pausado) más —cuando el dato
/// existe— el estado de su sesión de WhatsApp. Sin sombra; la jerarquía la da
/// `surface2` + padding + separación.
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
    return AppCard(
      key: Key('bots.tile.${bot.id}'),
      // push (no go): el detalle se apila sobre el listado para que el back
      // físico y la flecha del AppBar vuelvan al shell con la tab Bots activa.
      onTap: () => context.push('/bots/${bot.id}'),
      child: Row(
        children: <Widget>[
          const AppEntityIcon(icon: Icons.smart_toy_outlined),
          const SizedBox(width: AppTokens.sp4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(bot.name, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.sp3),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _StatusPill(paused: bot.paused),
              if (session != null) ...<Widget>[
                const SizedBox(height: AppTokens.sp2),
                _SessionPill(state: session),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Pill de estado del bot (no compite con el nombre). Activo → neutral con dot
/// `accent`; pausado → outline con dot neutro. No se usa fill primary ni
/// `success`: el dot cálido basta para comunicar "encendido".
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    if (paused) {
      return const AppPill.outline(label: 'Pausado', dot: AppPillDot.paused);
    }
    return const AppPill.neutral(label: 'Activo', dot: AppPillDot.active);
  }
}

/// Pill del estado de la sesión de WhatsApp del bot. Enlazado → neutral con dot
/// cálido (paridad con "Activo"); sin enlazar → outline apagado; los estados de
/// transición se resumen en un "Conectando…" honesto (el operador no distingue
/// pairing de connecting desde el listado).
class _SessionPill extends StatelessWidget {
  const _SessionPill({required this.state});

  final SessionState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      SessionState.connected => const AppPill.neutral(
        label: 'Enlazado',
        dot: AppPillDot.active,
      ),
      SessionState.disconnected => const AppPill.outline(
        label: 'Sin enlazar',
        dot: AppPillDot.paused,
      ),
      SessionState.pairing ||
      SessionState.connecting ||
      SessionState.reconnecting => const AppPill.neutral(
        label: 'Conectando…',
        dot: AppPillDot.paused,
      ),
    };
  }
}
