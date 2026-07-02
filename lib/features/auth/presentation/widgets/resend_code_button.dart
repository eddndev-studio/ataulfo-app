import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/design/widgets/app_button.dart';

/// Botón de "reenviar código" con enfriamiento propio. Tras un envío iniciado
/// queda deshabilitado [cooldownSeconds] segundos, mostrando la cuenta
/// regresiva, para que el operador no martillee el reenvío (y refleja el
/// enfriamiento que el backend impone de todos modos). El [onResend] dispara el
/// envío real (volver a pedir el código de reset o de verificación) y devuelve
/// si REALMENTE lo inició: cuando devuelve `false` (p. ej. falta el correo) el
/// enfriamiento NO arranca, para no fingir un envío que no ocurrió.
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({
    super.key,
    required this.onResend,
    this.enabled = true,
    this.cooldownSeconds = 60,
  });

  final bool Function() onResend;
  final bool enabled;
  final int cooldownSeconds;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  Timer? _timer;
  int _remaining = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resend() {
    if (_remaining > 0) return;
    // El enfriamiento sólo arranca si el envío se inició de verdad; un no-op
    // (p. ej. correo vacío) deja el botón disponible para reintentar.
    if (!widget.onResend()) return;
    setState(() => _remaining = widget.cooldownSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final onCooldown = _remaining > 0;
    final label = onCooldown
        ? 'Reenviar código (${_remaining}s)'
        : 'Reenviar código';
    return AppButton.text(
      label: label,
      fullWidth: true,
      onPressed: (widget.enabled && !onCooldown) ? _resend : null,
    );
  }
}
