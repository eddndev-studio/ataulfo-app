import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_starter_chip.dart';

/// Una sugerencia de arranque del asistente: etiqueta visible + texto con el
/// que PREFIJA el composer (puede diferir, p.ej. dejar el bot/flujo a
/// completar). El ícono da una pista del dominio de la acción.
class _Starter {
  const _Starter({
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

const List<_Starter> _starters = <_Starter>[
  _Starter(
    id: 'bots',
    label: '¿Cuántos bots tengo?',
    icon: Icons.smart_toy_outlined,
    prefill: '¿Cuántos bots tengo y cómo se llaman?',
  ),
  _Starter(
    id: 'pause',
    label: 'Pausar un bot',
    icon: Icons.pause_circle_outline,
    prefill: 'Pausa el bot ',
  ),
  _Starter(
    id: 'audit',
    label: 'Auditar un flujo',
    icon: Icons.fact_check_outlined,
    prefill: 'Audita el flujo ',
  ),
  _Starter(
    id: 'clone',
    label: 'Duplicar un flujo',
    icon: Icons.copy_all_outlined,
    prefill: 'Duplica el flujo ',
  ),
];

/// Estado vacío del hilo del asistente: un tip que orienta al operador y, debajo,
/// un `Wrap` centrado de sugerencias de arranque (cápsulas del kit). Un tap
/// PREFIJA el composer con el texto propuesto; el operador lo edita y envía.
class PaChatEmptyState extends StatelessWidget {
  const PaChatEmptyState({super.key, required this.onPrefill});

  /// Prefija el composer con el arranque de una sugerencia.
  final ValueChanged<String> onPrefill;

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
                for (final s in _starters)
                  AppStarterChip(
                    key: Key('pa.quick_action.${s.id}'),
                    label: s.label,
                    icon: s.icon,
                    onTap: () => onPrefill(s.prefill),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
