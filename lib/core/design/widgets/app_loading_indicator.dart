import 'package:flutter/material.dart';

import '../tokens.dart';

/// Indicador de carga canónico: un spinner ámbar de marca centrado, con un
/// rótulo opcional debajo. Unifica el `CircularProgressIndicator` que las
/// páginas montan mientras cargan — el `valueColor` de marca evita el azul
/// default de Material sobre el fondo oscuro.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.label});

  /// Texto opcional bajo el spinner (p. ej. "Cargando conversaciones…").
  final String? label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
          ),
          if (label != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp3),
            Text(
              label!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
          ],
        ],
      ),
    );
  }
}
