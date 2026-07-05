import 'package:flutter/material.dart';

import '../tokens.dart';

/// Una opción de un [AppSelectField]: el valor de dominio que representa y la
/// etiqueta legible que se muestra en el menú y en el campo cerrado.
class AppSelectOption<T> {
  const AppSelectOption(this.value, this.label);

  final T value;
  final String label;
}

/// Primitivo de selección del design system.
///
/// Comparte el lenguaje visual del [AppTextField] —píldora con fill translúcido
/// (`input`), radio `radiusField`, label arriba y glow de foco— pero
/// envuelve un `DropdownButton` en vez de un `TextField`. El dropdown va SIN su
/// decoración de Material (underline apagado, foco transparente): la píldora la
/// pinta el contenedor envolvente, igual que en el campo de texto.
///
/// El estado de foco se resuelve con un `FocusNode` y `setState` (rebuild
/// inmediato), de modo que el borde y el glow aparecen en el mismo frame en que
/// el dropdown gana foco (al abrirlo).
class AppSelectField<T> extends StatefulWidget {
  const AppSelectField({
    super.key,
    required this.label,
    this.helperText,
    this.hint,
    required this.value,
    required this.options,
    this.onChanged,
    this.enabled = true,
  });

  final String label;

  /// Texto de ayuda bajo el field, en `text2`. Null ⇒ sin ayuda.
  final String? helperText;

  /// Placeholder dentro del field mientras [value] es null, en `text2` para
  /// no confundirse con un valor elegido. Null ⇒ campo vacío sin selección.
  final String? hint;

  final T? value;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  @override
  State<AppSelectField<T>> createState() => _AppSelectFieldState<T>();
}

class _AppSelectFieldState<T> extends State<AppSelectField<T>> {
  // Mismo objetivo táctil que el campo de texto de una línea; el shell reserva
  // ese alto aunque el contenido mida menos.
  static const double _touchTarget = 48.0;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  // Rebuild inmediato hacia el estado enfocado/desenfocado: el borde y el glow
  // deben estar presentes en el primer frame tras ganar foco.
  void _onFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final focused = _focusNode.hasFocus;
    final radius = BorderRadius.circular(AppTokens.radiusField);

    // El borde reserva siempre 2px (transparente en reposo) para que enfocar no
    // salte el layout, igual que en el campo de texto.
    final borderColor = focused ? AppTokens.primary : Colors.transparent;

    // El glow acompaña al foco; con foco compactamos el fill a su equivalente
    // opaco para que la sombra no sangre hacia el interior translúcido.
    final List<BoxShadow>? boxShadow = focused
        ? const <BoxShadow>[
            BoxShadow(
              color: AppTokens.primaryGlow,
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ]
        : null;
    final fillColor = focused
        ? Color.alphaBlend(AppTokens.input, AppTokens.bgBase)
        : AppTokens.input;

    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          widget.label,
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _touchTarget),
          child: Container(
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: radius,
              border: Border.all(color: borderColor, width: 2),
              boxShadow: boxShadow,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sp4,
              vertical: AppTokens.sp1,
            ),
            child: DropdownButton<T>(
              value: widget.value,
              hint: widget.hint != null
                  ? Text(
                      widget.hint!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTokens.text2,
                      ),
                    )
                  : null,
              focusNode: _focusNode,
              isExpanded: true,
              isDense: true,
              // El shell ya pinta la píldora: el dropdown va sin línea inferior
              // ni fill de foco propios de Material.
              underline: const SizedBox.shrink(),
              focusColor: Colors.transparent,
              icon: const Icon(Icons.expand_more, color: AppTokens.text2),
              dropdownColor: AppTokens.surface2,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text1),
              onChanged: widget.enabled ? widget.onChanged : null,
              items: widget.options
                  .map(
                    (o) => DropdownMenuItem<T>(
                      value: o.value,
                      // Una línea con ellipsis: una opción larga no debe
                      // desbordar la píldora ni partirse en renglones.
                      child: Text(
                        o.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        if (widget.helperText != null) ...<Widget>[
          const SizedBox(height: AppTokens.sp1),
          Text(
            widget.helperText!,
            style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
          ),
        ],
      ],
    );

    // Disabled: atenuar el bloque con el mismo idioma que AppTextField/AppButton.
    return Opacity(opacity: widget.enabled ? 1.0 : 0.4, child: field);
  }
}
