import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_switch.dart';

/// Fila de un toggle de configuración: etiqueta + descripción a la izquierda,
/// [AppSwitch] a la derecha. La comparten los toggles de detalle (pausa, IA) y
/// las fichas de configuración. `onChanged` nulo la deja inhabilitada (mutación
/// en vuelo o toggle inerte por contexto).
class AppToggleRow extends StatelessWidget {
  const AppToggleRow({
    super.key,
    required this.switchKey,
    required this.label,
    required this.caption,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final String label;
  final String caption;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                caption,
                style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppTokens.sp4),
        AppSwitch(key: switchKey, value: value, onChanged: onChanged),
      ],
    );
  }
}
