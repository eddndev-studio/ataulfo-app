import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';

/// Tile información+control del editor de AIConfig: label + valor. Cuando es
/// editable, tocar el tile abre un selector en una hoja, así que el trailing es
/// el mismo chevron (`expand_more`, atenuado) que muestra un campo de selección
/// cerrado — el idioma de "esto despliega opciones". `onTap` nulo lo deja como
/// solo-lectura (sin chevron), con la nota "Fija del modelo" cuando el modelo no
/// soporta el campo.
class AiConfigStatTile extends StatelessWidget {
  const AiConfigStatTile({
    super.key,
    required this.tileKey,
    required this.label,
    required this.value,
    this.note,
    this.onTap,
  });

  final Key tileKey;
  final String label;
  final String value;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: tileKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppTokens.sp4),
        decoration: BoxDecoration(
          color: AppTokens.surface2,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(label, style: textTheme.labelSmall)),
                if (onTap != null)
                  const Icon(
                    Icons.expand_more,
                    size: 20,
                    color: AppTokens.text2,
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.sp1),
            Text(value, style: textTheme.titleMedium),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  note!,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTokens.text2,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
