import 'package:flutter/material.dart';

import '../tokens.dart';

/// Gutters horizontales según la jerarquía de la superficie.
///
/// Los scrollables que necesitan conservar su propio [ScrollView.padding]
/// usan estos valores directamente; el resto debe preferir los padres
/// semánticos de este archivo.
abstract final class AppPageGutters {
  /// Destinos principales del shell y paneles de gestión.
  static const double primary = AppTokens.sp5;

  /// Detalles, editores y formularios empujados sobre una página principal.
  static const double detail = AppTokens.sp6;
}

/// Padre de contenido para destinos principales y paneles de gestión.
///
/// Sólo fija el gutter horizontal canónico. El espacio vertical pertenece a
/// cada pantalla porque puede incluir headers, FABs o insets del sistema.
class AppPrimaryPageContainer extends StatelessWidget {
  const AppPrimaryPageContainer({
    super.key,
    required this.child,
    this.top = 0,
    this.bottom = 0,
  }) : assert(top >= 0),
       assert(bottom >= 0);

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppPageGutters.primary,
        top,
        AppPageGutters.primary,
        bottom,
      ),
      child: child,
    );
  }
}

/// Padre de contenido para detalles, editores y formularios secundarios.
///
/// Mantiene una separación mayor que las superficies primarias para expresar
/// el cambio de jerarquía sin inventar paddings locales por feature.
class AppDetailPageContainer extends StatelessWidget {
  const AppDetailPageContainer({
    super.key,
    required this.child,
    this.top = 0,
    this.bottom = 0,
  }) : assert(top >= 0),
       assert(bottom >= 0);

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppPageGutters.detail,
        top,
        AppPageGutters.detail,
        bottom,
      ),
      child: child,
    );
  }
}
