import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';

/// Superpone un retorno claro arriba a la izquierda en estados sin header.
///
/// La ruta de detalle no aporta AppBar, así que carga y error necesitan este
/// control para que el operador nunca quede atrapado.
class TemplateDetailBackOverlay extends StatelessWidget {
  const TemplateDetailBackOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: child),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back, color: AppTokens.text1),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ],
    );
  }
}
