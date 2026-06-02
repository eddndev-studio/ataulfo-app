import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_switch.dart';

/// Fila de un toggle de configuración del bot: etiqueta + descripción a la
/// izquierda, [AppSwitch] a la derecha. La comparten el toggle de pausa y el
/// de IA del detalle. `onChanged` nulo lo deja inhabilitado (mutación en vuelo
/// o toggle inerte por contexto).
class BotToggleRow extends StatelessWidget {
  const BotToggleRow({
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
