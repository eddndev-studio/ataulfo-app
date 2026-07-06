import 'package:flutter/widgets.dart';

/// Señal ambiental de motion del design system: ¿este subárbol anima?
///
/// La preferencia del usuario (Ajustes → Apariencia → Animaciones) vive
/// arriba del navigator; los primitivos del kit consultan [enabledOf] y
/// derivan sus duraciones con [durationOf] — apagado, toda micro-animación
/// colapsa a `Duration.zero` / estado final, sin ramas por widget.
///
/// Reglas de resolución:
///   - Sin [AppMotion] en el árbol (tests aislados, previews) ⇒ encendido.
///   - El reduce-motion del sistema (accesibilidad) SIEMPRE apaga, aunque la
///     preferencia esté encendida: `MediaQuery.disableAnimations` manda.
class AppMotion extends InheritedWidget {
  const AppMotion({super.key, required this.enabled, required super.child});

  /// Preferencia de la app (no incluye el reduce-motion del sistema; ese se
  /// resuelve por contexto en [enabledOf]).
  final bool enabled;

  /// ¿Debe animar este contexto? Combina la preferencia ambiental con el
  /// reduce-motion del sistema. Registra dependencia de ambos: un cambio en
  /// cualquiera reconstruye al consumidor.
  static bool enabledOf(BuildContext context) {
    final ambient = context.dependOnInheritedWidgetOfExactType<AppMotion>();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return (ambient?.enabled ?? true) && !reduceMotion;
  }

  /// [base] animando; `Duration.zero` apagado — los widgets implícitos
  /// (AnimatedScale, AnimatedSwitcher…) saltan directo al estado final.
  static Duration durationOf(BuildContext context, Duration base) =>
      enabledOf(context) ? base : Duration.zero;

  @override
  bool updateShouldNotify(AppMotion oldWidget) => enabled != oldWidget.enabled;
}
