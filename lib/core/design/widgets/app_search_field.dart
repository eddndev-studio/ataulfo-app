import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_text_field.dart';

/// Buscador canónico del design system.
///
/// A diferencia de un campo de formulario, comunica su función mediante una
/// lupa y un hint contextual: no añade un label externo que desplace el
/// contenido. La limpieza aparece sólo cuando hay texto, pero su espacio
/// táctil se superpone a la píldora para conservar el alto estable de 48 px.
///
/// El componente no implementa filtrado ni debounce. Cada feature conserva
/// esa política en [onChanged]; limpiar equivale a una edición con valor vacío.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    required this.controller,
    this.enabled = true,
    this.autofocus = false,
    this.autocorrect = false,
    this.onChanged,
    this.onSubmitted,
    this.clearButtonKey,
    this.semanticLabel,
  });

  /// Instrucción contextual que explica qué entidades o atributos se buscan.
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final bool autofocus;
  final bool autocorrect;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Key opcional del botón de limpieza para preservar anclas de cada feature.
  final Key? clearButtonKey;

  /// Nombre accesible persistente. Si se omite, se reutiliza [hint].
  final String? semanticLabel;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  static const double _clearTouchTarget = 48;

  late bool _hasText;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.isNotEmpty;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onControllerChanged);
    _hasText = widget.controller.text.isNotEmpty;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText == _hasText) return;
    setState(() => _hasText = hasText);
  }

  void _clear() {
    if (widget.controller.text.isEmpty) return;
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      textField: true,
      enabled: widget.enabled,
      label: widget.semanticLabel ?? widget.hint,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          AppTextField(
            hint: widget.hint,
            controller: widget.controller,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            autocorrect: widget.autocorrect,
            textInputAction: TextInputAction.search,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            prefixIcon: Icons.search,
            // El padding final de AppTextField aporta 16 px; reservar 32 px
            // completa el área de 48 px sobre la que se superpone el botón.
            suffix: const SizedBox(width: AppTokens.sp7),
          ),
          if (_hasText && widget.enabled)
            PositionedDirectional(
              top: 0,
              bottom: 0,
              end: 0,
              child: SizedBox(
                width: _clearTouchTarget,
                child: IconButton(
                  key: widget.clearButtonKey,
                  tooltip: 'Limpiar búsqueda',
                  onPressed: _clear,
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: AppTokens.text2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
