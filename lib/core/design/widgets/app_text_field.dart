import 'package:flutter/material.dart';

import '../tokens.dart';

/// Primitivo de input del design system.
///
/// Sustituye al `TextField` con `OutlineInputBorder` de Material. El
/// chrome canónico del kit es borderless con fill `surface3`: el
/// contenedor del campo aporta la jerarquía visual sin un border
/// explícito que compita con el contenido tipeado. La etiqueta vive
/// arriba del field como `labelSmall/text2`, no como floating label —
/// el operador la lee antes de tocar el campo y no necesita esperar
/// la animación.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.minLines,
    this.maxLines = 1,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Línea mínima visible (alinea con el contrato de `TextField.minLines`).
  /// `null` ⇒ se ajusta a `maxLines`. Útil con `maxLines > 1` para campos
  /// que crecen con el contenido pero arrancan ocupando varias líneas.
  final int? minLines;

  /// Líneas máximas visibles. `1` ⇒ single-line clásico (default). Mayor a 1
  /// ⇒ multiline (systemPrompt y similares). `null` ⇒ ilimitado (raro;
  /// preferir un valor explícito para que el layout sea predecible).
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppTokens.radiusField);
    final borderless = OutlineInputBorder(
      borderSide: BorderSide.none,
      borderRadius: radius,
    );
    final focused = OutlineInputBorder(
      borderSide: const BorderSide(color: AppTokens.primary, width: 1.5),
      borderRadius: radius,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        TextField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          minLines: minLines,
          maxLines: maxLines,
          style: textTheme.bodyMedium?.copyWith(color: AppTokens.text1),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            filled: true,
            fillColor: AppTokens.surface3,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sp4,
              vertical: AppTokens.sp3,
            ),
            border: borderless,
            enabledBorder: borderless,
            disabledBorder: borderless,
            focusedBorder: focused,
          ),
        ),
      ],
    );
  }
}
