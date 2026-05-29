import 'package:flutter/material.dart';

import '../tokens.dart';

/// Primitivo Switch del design system.
///
/// Toggle pill (track ~48x28, knob circular) que sigue la hoja de
/// componentes: el knob es claro ([AppTokens.text1]) en ambos estados y solo
/// el track cambia — `off` → track [AppTokens.surface3] con knob a la
/// izquierda; `on` → track [AppTokens.primary] con knob a la derecha.
/// El knob se desliza con [AnimatedAlign] en [AppTokens.durationFast] — leer
/// su alignment objetivo cubre a la vez posición y transición.
///
/// `onChanged` nulo deja el control deshabilitado: baja a opacity 0.4 y el
/// tap no togglea (mismo lenguaje que [AppButton]). Habilitado, un tap
/// dispara `onChanged(!value)` — el padre es dueño del estado.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  // Geometría del track pill y del knob; el knob deja un margen uniforme
  // contra el borde del track para leerse como pastilla flotante.
  static const double _trackWidth = 48.0;
  static const double _trackHeight = 28.0;
  static const double _knobInset = 3.0;
  static const double _knobSize = _trackHeight - _knobInset * 2;

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;

    // El track es el Container más cercano (ancestro directo) del
    // AnimatedAlign: su BoxDecoration porta el color que comunica el estado.
    final track = Container(
      width: _trackWidth,
      height: _trackHeight,
      padding: const EdgeInsets.symmetric(horizontal: _knobInset),
      decoration: BoxDecoration(
        color: value ? AppTokens.primary : AppTokens.surface3,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: AnimatedAlign(
        duration: AppTokens.durationFast,
        curve: AppTokens.ease,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: _knobSize,
          height: _knobSize,
          decoration: const BoxDecoration(
            color: AppTokens.text1,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );

    // El control visible mide 28 de alto; el hit-target llega a 48 con un
    // Center sobre un alto mínimo, sin meter Containers en la cadena que
    // los finds del contrato anclan al track y al knob.
    final tappable = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : () => onChanged!(!value),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        splashColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(child: track),
        ),
      ),
    );

    // Un único nodo de switch: ExcludeSemantics colapsa el nodo de botón del
    // InkWell; el rol/estado (toggled) y la operabilidad por accesibilidad los
    // porta este Semantics.
    return Semantics(
      container: true,
      toggled: value,
      enabled: !disabled,
      onTap: disabled ? null : () => onChanged!(!value),
      child: ExcludeSemantics(
        child: Opacity(opacity: disabled ? 0.4 : 1.0, child: tappable),
      ),
    );
  }
}
