import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

/// Primitivo de entrada para códigos de un solo uso (OTP) del design system.
///
/// El correo entrega un código de dígitos, no un enlace: el operador lo teclea
/// o lo pega. El campo lo captura con un `TextField` real —transparente y por
/// encima de las casillas— para heredar teclado numérico, pegado y el autofill
/// de OTP del sistema; encima pinta una fila de casillas visibles, una por
/// dígito, con la casilla activa resaltada en el mismo lenguaje de foco que
/// [AppTextField]. La captura se hace invisible con `Opacity` (no `Offstage`),
/// que la mantiene en el árbol de hit-testing y foco: tocar cualquier parte del
/// campo enfoca y abre el teclado.
class AppCodeField extends StatefulWidget {
  const AppCodeField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.length = 6,
    this.onCompleted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final bool enabled;

  /// Número de casillas (dígitos). El input se limita a esta longitud.
  final int length;

  /// Se invoca una vez cuando el código alcanza [length] dígitos. Útil para
  /// enviar automáticamente sin un tap extra; el llamador puede ignorarlo.
  final ValueChanged<String>? onCompleted;

  final bool autofocus;

  @override
  State<AppCodeField> createState() => _AppCodeFieldState();
}

class _AppCodeFieldState extends State<AppCodeField> {
  final FocusNode _focusNode = FocusNode();

  // Última longitud vista, para disparar onCompleted sólo en la transición a
  // "código completo" y no en cada reconstrucción mientras sigue lleno.
  int _lastLength = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
    _lastLength = widget.controller.text.length;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  void _onTextChanged() {
    final len = widget.controller.text.length;
    if (len == widget.length && _lastLength != widget.length) {
      widget.onCompleted?.call(widget.controller.text);
    }
    _lastLength = len;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final focused = _focusNode.hasFocus;
    // La casilla activa es la del siguiente dígito a escribir; cuando el código
    // está completo se ancla en la última para no salirse del rango.
    final activeIndex = text.length.clamp(0, widget.length - 1);

    final boxes = <Widget>[];
    for (var i = 0; i < widget.length; i++) {
      final digit = i < text.length ? text[i] : '';
      final isActive = focused && widget.enabled && i == activeIndex;
      boxes.add(
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: i == widget.length - 1 ? 0 : AppTokens.sp2,
            ),
            child: _CodeBox(
              boxKey: Key('app_code_field.box.$i'),
              digit: digit,
              active: isActive,
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.4,
      child: Stack(
        children: <Widget>[
          Row(children: boxes),
          // Captura transparente por encima de las casillas: recibe el tap
          // (enfoca y abre teclado) y todo el input real, pero no se ve.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                showCursor: false,
                // La selección interactiva se conserva a propósito: el toolbar
                // de "Pegar" (long-press) es la vía real de meter un OTP que
                // llegó por correo. `digitsOnly` sanea lo pegado.
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una casilla del código: fill translúcido del kit, borde primario cuando es
/// la activa (paridad con el foco de [AppTextField]) y el dígito centrado.
class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.boxKey,
    required this.digit,
    required this.active,
  });

  final Key boxKey;
  final String digit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: boxKey,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? Color.alphaBlend(AppTokens.input, AppTokens.bgBase)
            : AppTokens.input,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(
          color: active ? AppTokens.primary : AppTokens.divider,
          width: 2,
        ),
        boxShadow: active
            ? const <BoxShadow>[
                BoxShadow(
                  color: AppTokens.primaryGlow,
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Text(
        digit,
        style: const TextStyle(
          fontFamily: AppTokens.fontSans,
          fontSize: AppTokens.titleLSize,
          fontWeight: FontWeight.w600,
          color: AppTokens.text1,
        ),
      ),
    );
  }
}
