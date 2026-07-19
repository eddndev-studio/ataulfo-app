import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/entities/monitor_event.dart';
import '../cubit/monitor_live_cubit.dart';

/// Banner de alerta del bot (agent.alert) inline en el hilo del operador: una
/// señal crítica (p.ej. el bot perdió la sesión) no debe perderse en el log de
/// actividad. Muestra la alerta MÁS RECIENTE con título + detalle, persistente
/// aunque lleguen más eventos después; el operador la descarta con la X. Una
/// alerta nueva (otro timestamp) vuelve a aparecer. Solo ADMIN+ recibe eventos
/// (cubit cableado en el scope del hilo).
class AlertBanner extends StatefulWidget {
  const AlertBanner({super.key});

  @override
  State<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner> {
  /// `at` de la última alerta descartada: la oculta hasta que llegue otra.
  DateTime? _dismissed;

  @override
  Widget build(BuildContext context) {
    // La alerta vive RETENIDA en su propio campo (no es un paso de la traza
    // viva y el cierre de la corrida no debe barrerla).
    final alert = context.watch<MonitorLiveCubit>().state.alert;
    if (alert == null || alert.at == _dismissed) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    final semanticLabel =
        'Alerta del Asistente: ${alert.title.isNotEmpty ? alert.title : 'sin título'}'
        '${alert.detail.isNotEmpty ? '. ${alert.detail}' : ''}';
    return Semantics(
      liveRegion: true,
      container: true,
      label: semanticLabel,
      child: _banner(context, textTheme, alert),
    );
  }

  Widget _banner(
    BuildContext context,
    TextTheme textTheme,
    MonitorEvent alert,
  ) {
    return Container(
      key: const Key('monitor.alert_banner'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp3,
        vertical: AppTokens.sp1,
      ),
      padding: const EdgeInsets.all(AppTokens.sp3),
      decoration: BoxDecoration(
        color: AppTokens.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: AppTokens.danger),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppTokens.danger,
          ),
          const SizedBox(width: AppTokens.sp2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  alert.title.isNotEmpty ? alert.title : 'Alerta del Asistente',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppTokens.text1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (alert.detail.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    alert.detail,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTokens.text2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: const Key('monitor.alert_banner.dismiss'),
            tooltip: 'Descartar',
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, color: AppTokens.text2),
            onPressed: () => setState(() => _dismissed = alert.at),
          ),
        ],
      ),
    );
  }
}
