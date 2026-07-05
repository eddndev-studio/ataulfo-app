import 'package:flutter/material.dart';

import '../tokens.dart';

/// Encabezado de una sección dentro de una card: título en `titleMedium` y una
/// caption opcional atenuada a `text2` debajo. Es la anatomía que comparten las
/// subsecciones de las pantallas de ajustes (proveedor por modelo, valores por
/// defecto, parámetros del motor) para que su encabezado se vea igual en un solo
/// lugar. Sin caption pinta solo el título.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({super.key, required this.title, this.caption});

  final String title;

  /// Línea de apoyo bajo el título, en `text2`. Null ⇒ solo el título.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, style: textTheme.titleMedium),
        if (caption != null) ...<Widget>[
          const SizedBox(height: AppTokens.sp1),
          Text(
            caption!,
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
        ],
      ],
    );
  }
}
