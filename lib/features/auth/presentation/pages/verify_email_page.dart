import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_code_field.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../bloc/verify_email_bloc.dart';
import '../widgets/resend_code_button.dart';

/// Página de verificación de correo. Es presentación pura: la lógica vive en
/// `VerifyEmailBloc`.
///
/// El correo entrega un código de 6 dígitos, no un enlace: el operador escribe
/// su correo (precargado) y el código. `onSucceeded` es opcional para tests; en
/// la app real lo cabla el router (refresca la identidad para que el aviso se
/// resuelva y vuelve atrás). El flag `alreadyVerified` distingue el re-canje
/// idempotente del éxito recién hecho — sólo este último muestra un SnackBar.
///
/// `onResend` y `onSkip` sólo se pasan con sesión activa (el reenvío exige
/// Bearer y "omitir" lleva al home): sin sesión (deep-link público) no se
/// pintan.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({
    super.key,
    this.initialEmail = '',
    this.onSucceeded,
    this.onResend,
    this.onSkip,
  });

  final String initialEmail;
  final void Function({required bool alreadyVerified})? onSucceeded;

  /// Reenvío del código (requiere Bearer). Null sin sesión ⇒ no se pinta.
  final VoidCallback? onResend;

  /// "Omitir por ahora" → home. Null sin sesión ⇒ no se pinta.
  final VoidCallback? onSkip;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<VerifyEmailBloc>().add(
      VerifyEmailSubmitted(email: _email.text, code: _code.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onResend = widget.onResend;
    final onSkip = widget.onSkip;
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar correo')),
      body: SafeArea(
        child: BlocConsumer<VerifyEmailBloc, VerifyEmailState>(
          listener: (context, state) {
            if (state is VerifyEmailSucceeded) {
              // Sólo la verificación recién hecha merece un aviso; un re-canje
              // idempotente (ya estaba verificada) no muestra "éxito" nuevo.
              if (!state.alreadyVerified) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Verificación completada')),
                );
              }
              widget.onSucceeded?.call(alreadyVerified: state.alreadyVerified);
            }
          },
          builder: (context, state) {
            final submitting = state is VerifyEmailSubmitting;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 16),
                  Text(
                    'Te enviamos un código a tu correo. Escríbelo aquí para '
                    'verificar tu cuenta.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    key: const Key('verify.email'),
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
                    key: const Key('verify.code'),
                    controller: _code,
                    enabled: !submitting,
                  ),
                  const SizedBox(height: 24),
                  AppButton.filled(
                    key: const Key('verify.submit'),
                    label: 'Verificar',
                    fullWidth: true,
                    loading: submitting,
                    onPressed: submitting ? null : _submit,
                  ),
                  if (onResend != null) ...<Widget>[
                    const SizedBox(height: 8),
                    ResendCodeButton(
                      key: const Key('verify.resend'),
                      // Con sesión el reenvío siempre se inicia (Bearer válido);
                      // el enfriamiento arranca. El feedback de éxito/fallo lo
                      // muestra el aviso del ResendVerificationCubit en la ruta.
                      onResend: () {
                        onResend();
                        return true;
                      },
                      enabled: !submitting,
                    ),
                  ],
                  if (onSkip != null) ...<Widget>[
                    const SizedBox(height: 4),
                    AppButton.text(
                      key: const Key('verify.skip'),
                      label: 'Omitir por ahora',
                      fullWidth: true,
                      onPressed: submitting ? null : onSkip,
                    ),
                  ],
                  if (state is VerifyEmailFailed) ...<Widget>[
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
    );
  }

  String _messageFor(VerifyEmailFailureKind kind) => switch (kind) {
    VerifyEmailFailureKind.invalidInput =>
      'Escribe tu correo y el código de 6 dígitos',
    VerifyEmailFailureKind.invalidCode =>
      'Código incorrecto. Revísalo o reenvía uno nuevo.',
    VerifyEmailFailureKind.expiredCode =>
      'El código venció. Reenvía uno nuevo.',
    VerifyEmailFailureKind.network => 'Sin conexión, reintenta',
    VerifyEmailFailureKind.rateLimited =>
      'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
    VerifyEmailFailureKind.unknown => 'Algo salió mal, intenta de nuevo',
  };
}
