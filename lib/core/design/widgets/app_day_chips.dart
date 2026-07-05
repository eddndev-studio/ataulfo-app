import 'package:flutter/material.dart';

import '../tokens.dart';

/// Etiquetas visibles de los días en orden visual español (lunes primero).
/// `X` es miércoles por convención de calendarios en español; `M` es martes.
const List<String> _dayLabels = <String>['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// Nombres completos de los días, para el lector de pantalla: una sola letra
/// («X») no comunica el día a quien no ve la fila completa.
const List<String> _dayNames = <String>[
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Selector multi-select de días de la semana del design system.
///
/// Pinta siete chips circulares L M X J V S D en **orden visual español**
/// (índices 0..6, lunes primero, domingo al final). El índice es una
/// convención de UI, no del wire: un consumidor cuyo backend cuente los días
/// de otra forma (p. ej. domingo=0) debe mapear explícitamente en su capa.
///
/// Habla el idioma de selección de [AppChoiceChip]: opción latente con borde
/// hairline y label en `text2`; seleccionada con TINTE de marca (fondo
/// `primary` al 16% + borde y label en `primary`), nunca el fill amarillo
/// pleno de un CTA. A diferencia del chip de texto no se pinta check: el
/// glifo de una letra ES el contenido y un ícono lo desplazaría; el tinte y
/// el borde comunican la selección visualmente y `Semantics.selected` la
/// comunica por accesibilidad.
///
/// Cada día es un blanco táctil circular de al menos 44×44 px. El widget es
/// controlado: el tap no muta nada, emite por [onChanged] una **copia** de
/// [selected] con el día alternado y es el consumer quien decide el nuevo
/// estado. `onChanged` null deshabilita toda la fila (tinte a 0.4, sin tap).
class AppDayChips extends StatelessWidget {
  const AppDayChips({
    super.key,
    required this.selected,
    required this.onChanged,
    this.keyPrefix = 'app_day_chips',
  });

  /// Días seleccionados en índices de UI (0=lunes .. 6=domingo).
  final Set<int> selected;

  /// Recibe el nuevo set (copia) tras alternar el día tocado. Null ⇒
  /// deshabilitado.
  final ValueChanged<Set<int>>? onChanged;

  /// Prefijo de las keys de cada chip (`<keyPrefix>.day.<índice>`), para que
  /// cada superficie consumidora ancle sus pruebas sin depender del label.
  final String keyPrefix;

  void _toggle(int day) {
    final next = Set<int>.of(selected);
    if (!next.remove(day)) {
      next.add(day);
    }
    onChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTokens.sp1,
      runSpacing: AppTokens.sp1,
      children: <Widget>[
        for (var day = 0; day <= 6; day++)
          _DayChip(
            key: Key('$keyPrefix.day.$day'),
            label: _dayLabels[day],
            name: _dayNames[day],
            selected: selected.contains(day),
            onTap: onChanged == null ? null : () => _toggle(day),
          ),
      ],
    );
  }
}

/// Un día individual: círculo de 44px con la letra centrada.
class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
    required this.label,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String name;
  final bool selected;
  final VoidCallback? onTap;

  /// Diámetro del círculo — es a la vez el blanco táctil mínimo exigido.
  static const double _diameter = 44.0;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final foreground = selected ? AppTokens.primary : AppTokens.text2;

    final chip = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Container(
          width: _diameter,
          height: _diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Mismo tratamiento discreto que AppChoiceChip: tinte al
            // seleccionar, transparencia en reposo, y borde de 1px SIEMPRE
            // (primary / divider) para que la geometría no salte al alternar.
            color: selected
                ? AppTokens.primary.withValues(alpha: 0.16)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppTokens.primary : AppTokens.divider,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTokens.fontSans,
              fontSize: AppTokens.bodyMSize,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ),
    );

    // Un único nodo accesible por día: rol de botón, nombre completo del día
    // y estado de selección. ExcludeSemantics colapsa el InkWell y la letra.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: !disabled,
      label: name,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Opacity(opacity: disabled ? 0.4 : 1.0, child: chip),
      ),
    );
  }
}
