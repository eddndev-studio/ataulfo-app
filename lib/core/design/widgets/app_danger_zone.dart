import 'package:flutter/material.dart';

import '../tokens.dart';

/// Sección "Zona peligrosa" del design system: heading fijo + caption de
/// advertencia + acciones destructivas apiladas ([AppButton.danger] en los
/// callsites). Vive en el kit porque varias pantallas de configuración cierran
/// con ella y su anatomía debe ser idéntica en todas.
///
/// Abre con un hairline propio: la zona es siempre la sección final de la
/// página y el corte visual respecto al contenido operativo es parte de la
/// advertencia, no una decisión de cada pantalla.
class AppDangerZone extends StatelessWidget {
  const AppDangerZone({
    super.key,
    required this.caption,
    required this.actions,
  });

  /// Advertencia en lenguaje llano de qué se rompe y si hay vuelta atrás.
  final String caption;

  /// Acciones destructivas, en orden de menor a mayor severidad.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(color: AppTokens.divider, height: 1),
        const SizedBox(height: AppTokens.sp6),
        Text('Zona peligrosa', style: textTheme.titleMedium),
        const SizedBox(height: AppTokens.sp2),
        Text(
          caption,
          style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp4),
        for (var i = 0; i < actions.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppTokens.sp3),
          actions[i],
        ],
      ],
    );
  }
}
