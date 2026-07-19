import 'package:flutter/material.dart';

import '../tokens.dart';

/// Progreso indeterminado para espacios compactos como filas, miniaturas o
/// botones. Los estados que ocupan una página completa usan
/// `AppLoadingIndicator` en su lugar.
class AppInlineLoadingIndicator extends StatelessWidget {
  const AppInlineLoadingIndicator({
    super.key,
    this.size = 20,
    this.color = AppTokens.primary,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
