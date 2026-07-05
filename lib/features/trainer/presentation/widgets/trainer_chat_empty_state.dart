import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_starter_chip.dart';

/// Sugerencias de arranque del entrenador. Un tap PREFIJA el composer con el
/// texto (el operador lo edita y envía); no auto-envía un turno.
const List<String> _starters = <String>[
  '¿Qué necesitas saber de mi negocio?',
  'Muéstrame el prompt actual',
  'Resume el workspace',
  'Define el tono de respuesta',
  'Mejora el prompt',
];

/// Estado vacío del hilo del entrenador: un tip que orienta al operador y,
/// debajo, un `Wrap` centrado de sugerencias de arranque (cápsulas del kit).
/// Ocupa el área del chat —que de otro modo quedaría en blanco— y es
/// scrolleable para que el teclado no lo desborde.
class TrainerChatEmptyState extends StatelessWidget {
  const TrainerChatEmptyState({super.key, required this.onPrefill});

  /// Prefija el composer con la sugerencia elegida.
  final ValueChanged<String> onPrefill;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('trainer.empty_hint'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.school_outlined,
              size: 48,
              color: AppTokens.primary,
            ),
            const SizedBox(height: AppTokens.sp3),
            Text(
              'Entrena a tu bot',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(color: AppTokens.text1),
            ),
            const SizedBox(height: AppTokens.sp2),
            Text(
              'Cuéntale al entrenador sobre tu negocio —menú, horarios, tono— y '
              'él irá afinando el prompt y el workspace por ti. Empieza con una '
              'sugerencia o escribe tu primer mensaje.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppTokens.sp2,
              runSpacing: AppTokens.sp2,
              children: <Widget>[
                for (var i = 0; i < _starters.length; i++)
                  AppStarterChip(
                    key: Key('trainer.chip.$i'),
                    label: _starters[i],
                    onTap: () => onPrefill(_starters[i]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
