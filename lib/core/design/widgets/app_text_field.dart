import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

/// Primitivo de input del design system.
///
/// La forma canónica del kit es una píldora con fill translúcido: el borde y
/// el glow de foco no son decoración del `TextField` de Material —no caben en
/// un `InputDecoration`, que no admite `boxShadow`— sino de un contenedor
/// envolvente que pinta la píldora. El `TextField` interior va borderless y
/// solo aporta el texto, el hint y el comportamiento de edición.
///
/// La etiqueta vive arriba del field como caption (`labelSmall/text2`), no
/// como floating label: el operador la lee antes de tocar el campo y no
/// espera ninguna animación. El estado de foco se resuelve con un
/// `FocusNode` y `setState` (rebuild inmediato), no con una transición
/// animada, para que el borde y el glow aparezcan en el mismo frame.
class AppTextField extends StatefulWidget {
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
    this.keyboardType,
    this.inputFormatters,
    this.errorText,
    this.helperText,
    this.obscureText = false,
    this.obscureToggle = false,
    this.autocorrect = true,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
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

  /// Tipo de teclado virtual que se solicita al sistema operativo. `null`
  /// usa el default del platform (texto). `TextInputType.number` muestra el
  /// teclado numérico — control suave, no impide pegado ni teclado físico.
  final TextInputType? keyboardType;

  /// Formatters aplicados al input antes de propagar al controller. Son la
  /// red de seguridad de validación (ej. `digitsOnly`), independiente del
  /// teclado solicitado.
  final List<TextInputFormatter>? inputFormatters;

  /// Mensaje de error. No nulo ⇒ el campo entra en estado de error: borde y
  /// label en `danger`, y el mensaje se muestra bajo el field. El error
  /// gana sobre el foco (un campo inválido se ve inválido aunque esté
  /// enfocado).
  final String? errorText;

  /// Texto de ayuda bajo el field, en `text2`. Lo sustituye [errorText]
  /// cuando el campo está en error — no se muestran ambos a la vez.
  final String? helperText;

  /// Enmascara el contenido (puntos en vez de glifos) para campos de
  /// contraseña. Material exige `maxLines == 1` cuando es `true`; el default
  /// de `maxLines` ya lo cumple.
  final bool obscureText;

  /// Cuando es `true` junto con [obscureText], pinta un botón de ojo al final
  /// del campo que alterna la ocultación internamente (mostrar/ocultar la
  /// contraseña). Default `false` ⇒ sin botón, comportamiento idéntico al
  /// previo (backward-compatible). Sin [obscureText] no hace nada (no hay
  /// contenido que ocultar).
  final bool obscureToggle;

  /// Autocorrección del teclado. Se desactiva en campos donde el corrector
  /// estorba (email, identificadores) para que no altere lo tecleado.
  final bool autocorrect;

  /// Ícono líder dentro de la píldora (p. ej. la lupa de un buscador). Se
  /// pinta con el idioma discreto del kit (20px, `text2`): acompaña al hint,
  /// no compite con el contenido.
  final IconData? prefixIcon;

  /// Widget libre al final de la píldora (p. ej. el botón de limpiar de un
  /// buscador). Es un slot: la visibilidad y el comportamiento los gobierna
  /// el call site. Cuando [obscureToggle] aplica, el botón de ojo gana este
  /// slot (un campo de contraseña no es un buscador).
  final Widget? suffix;

  /// Notificación por edición del texto (pass-through a `TextField.onChanged`).
  /// Útil cuando el caller reacciona tecla a tecla (debounce de búsqueda) en
  /// vez de escuchar el controller.
  final ValueChanged<String>? onChanged;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  // Objetivo táctil (alto) de un campo de una línea. El radio del text area se
  // deriva de aquí (_touchTarget / 2) para igualar la curvatura REAL de la
  // píldora de una línea, en vez de un pill pleno que sobre una caja alta
  // curva las esquinas a alto/2 y se ve deforme.
  static const double _touchTarget = 48.0;

  final FocusNode _focusNode = FocusNode();

  // Ocultación efectiva cuando el toggle de visibilidad está activo: arranca
  // espejando `widget.obscureText` y el botón de ojo la alterna. Sin toggle no
  // se consulta (la ocultación la gobierna `widget.obscureText` directo).
  late bool _obscured = widget.obscureText;

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

  // Rebuild inmediato del shell hacia su estado enfocado/desenfocado. Un
  // setState (no una animación) garantiza que el borde y el glow estén
  // presentes en el primer frame tras ganar foco.
  void _onFocusChanged() {
    // Al GANAR foco, un controller pre-llenado (`TextEditingController(text:…)`)
    // trae la selección en offset -1 (inválida); la plataforma la trata
    // seleccionando TODO el texto, lo que impide colocar el cursor para editar.
    // Colapsamos el caret al final: el primer foco posiciona el cursor (y un tap
    // posterior lo recoloca donde se toque). Sólo al ganar foco y sólo si la
    // selección es inválida — nunca pisamos una selección que el usuario ya hizo.
    // Se hace aquí (no en initState) porque mutar el controller durante el build
    // notificaría a sus listeners (el padre) en pleno build → setState ilegal.
    if (_focusNode.hasFocus) {
      final c = widget.controller;
      if (c.text.isNotEmpty && !c.selection.isValid) {
        c.selection = TextSelection.collapsed(offset: c.text.length);
      }
    }
    setState(() {});
  }

  // El toggle de visibilidad sólo aplica a campos enmascarados: ocultar texto
  // ya visible no tiene sentido. Sin obscureText el botón no se pinta.
  bool get _hasToggle => widget.obscureToggle && widget.obscureText;

  // Valor de ocultación que recibe el TextField: con toggle activo lo gobierna
  // el estado interno (alternable); sin toggle, el flag crudo del widget.
  bool get _effectiveObscure => _hasToggle ? _obscured : widget.obscureText;

  // Botón de ojo del toggle de visibilidad. Mostrar/ocultar es un toggle del
  // estado interno; rebuild inmediato.
  Widget _eyeButton() => IconButton(
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(),
    visualDensity: VisualDensity.compact,
    icon: Icon(
      _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      color: AppTokens.text2,
      size: 20,
    ),
    onPressed: () => setState(() => _obscured = !_obscured),
  );

  // Adorna el campo con los extras de la píldora: ícono líder ([prefixIcon])
  // y/o widget final (el botón de ojo cuando el toggle aplica; si no, el
  // [suffix] del caller). Sin adornos devuelve el campo intacto — esos call
  // sites conservan el layout previo (un único hijo en la píldora, sin Row).
  Widget _withAdornments(Widget field) {
    final prefix = widget.prefixIcon;
    final Widget? suffix = _hasToggle ? _eyeButton() : widget.suffix;
    if (prefix == null && suffix == null) return field;
    return Row(
      children: <Widget>[
        if (prefix != null) ...<Widget>[
          Icon(prefix, size: 20, color: AppTokens.text2),
          const SizedBox(width: AppTokens.sp2),
        ],
        Expanded(child: field),
        ?suffix,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Una línea: píldora (radiusField). Multilínea (text area): rect redondeado
    // con el mismo radio efectivo que la píldora de una línea (_touchTarget/2).
    final isMultiline =
        widget.maxLines == null ||
        widget.maxLines! > 1 ||
        (widget.minLines ?? 1) > 1;
    final radius = BorderRadius.circular(
      isMultiline ? _touchTarget / 2 : AppTokens.radiusField,
    );

    final hasError = widget.errorText != null;
    final focused = _focusNode.hasFocus;

    // El error gana sobre el foco; el borde mide siempre 2px para que
    // enfocar no salte el layout. En reposo el borde es divider (hairline
    // visible): el fill translúcido desaparece sobre superficies elevadas
    // (surface2 de un acordeón, p. ej.) y sin borde el campo se leía como
    // texto suelto — un campo debe verse campo sobre cualquier superficie.
    final Color borderColor;
    if (hasError) {
      borderColor = AppTokens.danger;
    } else if (focused) {
      borderColor = AppTokens.primary;
    } else {
      borderColor = AppTokens.divider;
    }

    // El glow solo acompaña al foco limpio (sin error): comunica «aquí está
    // el cursor», no «hay un problema».
    final List<BoxShadow>? boxShadow = (focused && !hasError)
        ? const <BoxShadow>[
            BoxShadow(
              color: AppTokens.primaryGlow,
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ]
        : null;

    // El glow de foco es un boxShadow detrás de la caja. Con el fill translúcido
    // (`input` = gris al 60%) la sombra se veía A TRAVÉS hacia el interior, como
    // un glow interno. Al enfocar (única situación con glow) compactamos el fill
    // a su equivalente OPACO (input compuesto sobre bgBase): la parte interna de
    // la sombra queda tapada y solo se ve el halo por fuera del borde. En reposo
    // y en error se conserva el fill translúcido (no hay sombra que sangre).
    final fillColor = (focused && !hasError)
        ? Color.alphaBlend(AppTokens.input, AppTokens.bgBase)
        : AppTokens.input;

    final labelColor = hasError ? AppTokens.danger : AppTokens.text2;
    final helperOrError = widget.errorText ?? widget.helperText;
    final helperColor = hasError ? AppTokens.danger : AppTokens.text2;

    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          widget.label,
          style: textTheme.labelSmall?.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppTokens.sp1),
        // El kit fija un objetivo táctil de 48px: el shell garantiza ese alto
        // mínimo aunque el texto de una sola línea mida menos. El ConstrainedBox
        // envuelve el Container por fuera para que la píldora siga siendo el
        // único contenedor con BoxDecoration.
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _touchTarget),
          child: Container(
            // Una línea: centrado vertical dentro del alto mínimo (si no, el
            // texto quedaría pegado arriba). Multilínea: el texto arranca arriba
            // y crece hacia abajo.
            alignment: isMultiline ? Alignment.topLeft : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: radius,
              border: Border.all(color: borderColor, width: 2),
              boxShadow: boxShadow,
            ),
            // Multilínea necesita más respiro vertical para no rozar el borde;
            // una línea va ajustada porque el alto mínimo ya la centra.
            padding: EdgeInsets.symmetric(
              horizontal: AppTokens.sp4,
              vertical: isMultiline ? AppTokens.sp3 : AppTokens.sp1,
            ),
            child: _withAdornments(
              TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                textInputAction: widget.textInputAction,
                onSubmitted: widget.onSubmitted,
                onChanged: widget.onChanged,
                minLines: widget.minLines,
                maxLines: widget.maxLines,
                keyboardType: widget.keyboardType,
                inputFormatters: widget.inputFormatters,
                obscureText: _effectiveObscure,
                autocorrect: widget.autocorrect,
                style: textTheme.bodyMedium?.copyWith(color: AppTokens.text1),
                // Borderless y sin relleno/padding propios: la píldora la pinta
                // el Container, y el padding lo gobierna SIEMPRE el shell. Un
                // borde o un fill aquí competiría con el del contenedor y haría
                // al campo sensible al tema de Material por debajo.
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  filled: false,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                  hintText: widget.hint,
                  hintStyle: textTheme.bodyMedium?.copyWith(
                    color: AppTokens.text2,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (helperOrError != null) ...<Widget>[
          const SizedBox(height: AppTokens.sp1),
          Text(
            helperOrError,
            style: textTheme.labelSmall?.copyWith(color: helperColor),
          ),
        ],
      ],
    );

    // Disabled: atenuar todo el bloque con el mismo idioma que AppButton.
    return Opacity(opacity: widget.enabled ? 1.0 : 0.4, child: field);
  }
}
