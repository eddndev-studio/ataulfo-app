import 'package:flutter/material.dart';

import '../tokens.dart';

/// Capa canónica para indicar que una miniatura o tarjeta está seleccionada.
/// El widget ocupa las restricciones de su padre; normalmente se monta dentro
/// de un `Positioned.fill` en un `Stack`.
class AppSelectionOverlay extends StatelessWidget {
  const AppSelectionOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Seleccionado',
      child: const ColoredBox(
        color: AppTokens.primaryGlow,
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.all(AppTokens.sp1),
            child: Icon(Icons.check_circle, color: AppTokens.primary, size: 22),
          ),
        ),
      ),
    );
  }
}
