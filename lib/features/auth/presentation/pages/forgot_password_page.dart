import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../bloc/forgot_password_bloc.dart';

/// Página de "olvidé mi contraseña". Es presentación pura: la lógica vive en
/// `ForgotPasswordBloc`.
///
/// `onCodeSent` y `onHaveCode` son opcionales para tests; en la app real los
/// cabla el router. Al aceptar el backend la solicitud (202, incondicional),
/// `onCodeSent` lleva el correo escrito a la pantalla de reset para escribir
/// ahí el código; "Ya tengo un código" (`onHaveCode`) va a la misma pantalla
/// sin arrastrar correo. El backend responde 202 sin distinguir si la cuenta
/// existe, así que ningún copy confirma la existencia.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.onCodeSent, this.onHaveCode});

  /// Navegación a la pantalla de reset llevando el correo escrito. Se invoca al
  /// transicionar a `Sent` (backend aceptó el envío). El router la cabla a
  /// `/reset-password?email=…`.
  final ValueChanged<String>? onCodeSent;

  /// Navegación a la pantalla de reset SIN correo ("ya tengo un código").
  final VoidCallback? onHaveCode;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    _email.addListener(_onChanged);
  }

  @override
  void dispose() {
    _email.removeListener(_onChanged);
    _email.dispose();
    super.dispose();
  }

  // Rebuild para re-evaluar el gate del botón en cada tecla.
  void _onChanged() => setState(() {});

  // Igual que RegisterPage: el gate sólo exige texto; el formato fino del
  // email lo juzga el backend (202 ciego), no el cliente.
  bool get _canSubmit => _email.text.isNotEmpty;

  void _submit() {
    context.read<ForgotPasswordBloc>().add(
      ForgotPasswordSubmitted(email: _email.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: SafeArea(
        child: BlocConsumer<ForgotPasswordBloc, ForgotPasswordState>(
          listener: (context, state) {
            if (state is ForgotPasswordSent) {
              widget.onCodeSent?.call(_email.text);
            }
          },
          builder: (context, state) {
            final submitting = state is ForgotPasswordSubmitting;
            final sent = state is ForgotPasswordSent;
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.sp6,
                vertical: AppTokens.sp7,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: AppTokens.sp4),
                  Text(
                    'Te enviaremos un código para restablecer tu contraseña.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTokens.sp6),
                  AppTextField(
                    key: const Key('forgot.email'),
                    label: 'Email',
                    hint: 'tucorreo@dominio.com',
                    controller: _email,
                    enabled: !submitting,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                  ),
                  const SizedBox(height: AppTokens.sp6),
                  AppButton.filled(
                    label: 'Enviar instrucciones',
                    fullWidth: true,
                    loading: submitting,
                    onPressed: (_canSubmit && !submitting) ? _submit : null,
                  ),
                  const SizedBox(height: AppTokens.sp2),
                  TextButton(
                    onPressed: submitting ? null : widget.onHaveCode,
                    child: const Text('Ya tengo un código'),
                  ),
                  if (sent) ...<Widget>[
                    const SizedBox(height: AppTokens.sp4),
                    Text(
                      'Si existe una cuenta con ese correo, te enviamos '
                      'instrucciones para restablecer la contraseña.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                  if (state is ForgotPasswordFailed) ...<Widget>[
                    const SizedBox(height: AppTokens.sp4),
                    Text(
                      _messageFor(state.kind),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTokens.danger,
                      ),
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

  String _messageFor(ForgotPasswordFailureKind kind) => switch (kind) {
    ForgotPasswordFailureKind.rateLimited =>
      'Demasiados intentos, espera un momento',
    ForgotPasswordFailureKind.network => 'Sin conexión, reintenta',
    ForgotPasswordFailureKind.unknown => 'Algo salió mal, intenta de nuevo',
  };
}
