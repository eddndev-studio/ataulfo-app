import 'package:flutter/material.dart';

import '../safe_bottom.dart';
import '../tokens.dart';

/// Composer de chat del design system: la caja de redacción canónica de
/// TODAS las superficies conversacionales (hilo real, entrenador, probar
/// bot). Barra `surface1` con divisor superior y safe-area inferior;
/// adentro, acciones leading opcionales + campo píldora multilinea con el
/// idioma de foco de [AppTextField] (borde primary + glow en el mismo
/// frame) + botón circular de enviar.
///
/// El envío es del composer: recorta el texto, ignora vacíos, limpia el
/// campo y entrega el resultado por [onSend]. El botón solo se habilita
/// con texto no vacío. Un caller que necesite insertar texto (respuestas
/// rápidas, captions) pasa su propio [controller]; si no, el composer crea
/// y posee el suyo.
class AppChatComposer extends StatefulWidget {
  const AppChatComposer({
    super.key,
    required this.onSend,
    this.hint = 'Mensaje',
    this.enabled = true,
    this.leading = const <Widget>[],
    this.controller,
    this.fieldKey,
    this.sendKey,
  });

  /// Recibe el texto ya recortado; nunca se llama con vacío.
  final ValueChanged<String> onSend;

  final String hint;

  /// `false` bloquea campo y envío (turno en vuelo en las superficies
  /// síncronas). El composer se atenúa como los demás controles del kit.
  final bool enabled;

  /// Acciones a la izquierda del campo (adjuntar, respuestas rápidas…).
  final List<Widget> leading;

  /// Controller externo opcional — para callers que insertan texto. El
  /// composer NO lo dispone (su dueño es el caller).
  final TextEditingController? controller;

  /// Keys del campo y del botón, para que cada superficie conserve las
  /// suyas en tests.
  final Key? fieldKey;
  final Key? sendKey;

  @override
  State<AppChatComposer> createState() => _AppChatComposerState();
}

class _AppChatComposerState extends State<AppChatComposer> {
  /// Objetivo táctil del kit; el radio de la píldora se deriva de aquí
  /// (mismo criterio que el text area de `AppTextField`).
  static const double _touchTarget = 48.0;

  TextEditingController? _owned;
  final FocusNode _focusNode = FocusNode();

  TextEditingController get _ctrl =>
      widget.controller ?? (_owned ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
    _focusNode.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(AppChatComposer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _owned)?.removeListener(_onChanged);
      _ctrl.addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _owned?.dispose();
    _focusNode.removeListener(_onChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    _ctrl.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canSend = widget.enabled && _ctrl.text.trim().isNotEmpty;
    final focused = _focusNode.hasFocus;
    final radius = BorderRadius.circular(_touchTarget / 2);

    // Idioma de foco de AppTextField: borde primary + glow, fill compactado
    // a opaco para que la sombra no sangre hacia adentro.
    final fillColor = focused
        ? Color.alphaBlend(AppTokens.input, AppTokens.bgBase)
        : AppTokens.input;

    final field = Container(
      constraints: const BoxConstraints(minHeight: _touchTarget),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: radius,
        border: Border.all(
          color: focused ? AppTokens.primary : Colors.transparent,
          width: 2,
        ),
        boxShadow: focused
            ? const <BoxShadow>[
                BoxShadow(
                  color: AppTokens.primaryGlow,
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp4,
        vertical: AppTokens.sp2,
      ),
      child: TextField(
        key: widget.fieldKey,
        controller: _ctrl,
        focusNode: _focusNode,
        enabled: widget.enabled,
        minLines: 1,
        maxLines: 5,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: textTheme.bodyLarge?.copyWith(color: AppTokens.text1),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          filled: false,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          hintText: widget.hint,
          hintStyle: textTheme.bodyLarge?.copyWith(color: AppTokens.text2),
        ),
      ),
    );

    // Botón circular de enviar: relleno primary con glifo oscuro (idioma de
    // AppButton.filled), atenuado cuando no hay nada que enviar.
    final send = SizedBox(
      width: _touchTarget,
      height: _touchTarget,
      child: Material(
        color: canSend ? AppTokens.primary : AppTokens.surface3,
        shape: const CircleBorder(),
        child: InkWell(
          key: widget.sendKey,
          customBorder: const CircleBorder(),
          onTap: canSend ? _send : null,
          child: Icon(
            Icons.send_rounded,
            size: 22,
            color: canSend ? AppTokens.onPrimary : AppTokens.text2,
            semanticLabel: 'Enviar',
          ),
        ),
      ),
    );

    final bar = Container(
      key: const Key('app_chat_composer.bar'),
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp3,
        AppTokens.sp2,
        AppTokens.sp3,
        AppTokens.sp2 + context.safeBottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppTokens.surface1,
        border: Border(top: BorderSide(color: AppTokens.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          ...widget.leading,
          if (widget.leading.isNotEmpty) const SizedBox(width: AppTokens.sp1),
          Expanded(child: field),
          const SizedBox(width: AppTokens.sp2),
          send,
        ],
      ),
    );

    return Opacity(opacity: widget.enabled ? 1.0 : 0.4, child: bar);
  }
}
