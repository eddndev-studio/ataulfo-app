import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_code_field.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../bloc/forgot_password_bloc.dart';
import '../bloc/reset_password_bloc.dart';
import '../widgets/resend_code_button.dart';

/// Página de restablecimiento de contraseña. Es presentación pura: la lógica
/// vive en `ResetPasswordBloc`.
///
/// El correo entrega un código de 6 dígitos, no un enlace: el operador escribe
/// su correo (precargado desde el flujo de "olvidé mi contraseña", editable
/// para cubrir "ya tengo un código"), el código y la contraseña nueva.
/// `onSucceeded` es opcional para tests; en la app real lo cabla el router
/// (cierra la sesión local —el backend ya revocó las familias de refresh— y
/// rutea al login). "Reenviar código" vuelve a pedir el correo de reset con el
/// `ForgotPasswordBloc` de esta ruta, con su propio enfriamiento.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    this.initialEmail = '',
    this.onSucceeded,
  });

  /// Correo precargado (lo pasa el router desde el query `?email=`). Editable.
  final String initialEmail;
  final VoidCallback? onSucceeded;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<ResetPasswordBloc>().add(
      ResetPasswordSubmitted(
        email: _email.text,
        code: _code.text,
        newPassword: _password.text,
      ),
    );
  }

  bool _resend() {
    final email = _email.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe tu correo para reenviar el código'),
        ),
      );
      return false;
    }
    context.read<ForgotPasswordBloc>().add(
      ForgotPasswordSubmitted(email: email),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva contraseña')),
      body: SafeArea(
        // Feedback del reenvío: el `ForgotPasswordBloc` de esta ruta emite Sent
        // (correo aceptado, incondicional) o Failed; sin este listener nadie lo
        // escucharía y el reenvío sería mudo.
        child: BlocListener<ForgotPasswordBloc, ForgotPasswordState>(
          listener: (context, state) {
            if (state is ForgotPasswordSent) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Te reenviamos el código')),
              );
            } else if (state is ForgotPasswordFailed) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'No pudimos reenviar el código. Espera un momento para '
                    'reintentar.',
                  ),
                ),
              );
            }
          },
          child: BlocConsumer<ResetPasswordBloc, ResetPasswordState>(
            listener: (context, state) {
              if (state is ResetPasswordSucceeded) {
                widget.onSucceeded?.call();
              }
            },
            builder: (context, state) {
              final submitting = state is ResetPasswordSubmitting;
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 16),
                    Text(
                      'Te enviamos un código a tu correo (si existe una cuenta). '
                      'Escríbelo aquí y elige una contraseña nueva. El código '
                      'vence en 15 minutos.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    AppTextField(
                      key: const Key('reset.email'),
                      label: 'Email',
                      hint: 'tucorreo@dominio.com',
                      controller: _email,
                      enabled: !submitting,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Código',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppTokens.text2,
                      ),
                    ),
                    const SizedBox(height: AppTokens.sp1),
                    AppCodeField(
                      key: const Key('reset.code'),
                      controller: _code,
                      enabled: !submitting,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      key: const Key('reset.password'),
                      label: 'Nueva contraseña',
                      hint: 'Mínimo 12 caracteres',
                      controller: _password,
                      enabled: !submitting,
                      obscureText: true,
                      obscureToggle: true,
                    ),
                    const SizedBox(height: 24),
                    AppButton.filled(
                      key: const Key('reset.submit'),
                      label: 'Restablecer contraseña',
                      fullWidth: true,
                      loading: submitting,
                      onPressed: submitting ? null : _submit,
                    ),
                    const SizedBox(height: 8),
                    ResendCodeButton(
                      key: const Key('reset.resend'),
                      onResend: _resend,
                      enabled: !submitting,
                    ),
                    if (state is ResetPasswordFailed) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        _messageFor(state.kind),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTokens.danger),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _messageFor(ResetPasswordFailureKind kind) => switch (kind) {
    ResetPasswordFailureKind.invalidInput =>
      'Escribe tu correo y el código de 6 dígitos',
    ResetPasswordFailureKind.passwordTooShort =>
      'La contraseña debe tener al menos 12 caracteres',
    ResetPasswordFailureKind.invalidCode =>
      'Código incorrecto. Revísalo o reenvía uno nuevo.',
    ResetPasswordFailureKind.expiredCode =>
      'El código venció. Reenvía uno nuevo.',
    ResetPasswordFailureKind.network => 'Sin conexión, reintenta',
    ResetPasswordFailureKind.rateLimited =>
      'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
    ResetPasswordFailureKind.unknown => 'Algo salió mal, intenta de nuevo',
  };
}
