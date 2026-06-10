import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../bloc/forgot_password_bloc.dart';

/// Página de "olvidé mi contraseña". Es presentación pura: la lógica vive en
/// `ForgotPasswordBloc`.
///
/// `onHaveCode` es opcional para tests; en la app real lo cabla el router
/// (empuja la pantalla de reset). El backend responde 202 sin distinguir si la
/// cuenta existe; por eso el estado `Sent` pinta un copy condicional ("si
/// existe una cuenta…") que nunca confirma la existencia ni que el correo se
/// haya enviado.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.onHaveCode});

  /// Navegación a la pantalla de reset (pegar el enlace/código). Opcional para
  /// tests; el router la inyecta para mantener la página sin go_router.
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
        child: BlocBuilder<ForgotPasswordBloc, ForgotPasswordState>(
          builder: (context, state) {
            final submitting = state is ForgotPasswordSubmitting;
            final sent = state is ForgotPasswordSent;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 16),
                  Text(
                    'Te enviaremos un enlace para restablecer tu contraseña.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    key: const Key('forgot.email'),
                    label: 'Email',
                    hint: 'tucorreo@dominio.com',
                    controller: _email,
                    enabled: !submitting,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 24),
                  AppButton.filled(
                    label: 'Enviar instrucciones',
                    fullWidth: true,
                    loading: submitting,
                    onPressed: (_canSubmit && !submitting) ? _submit : null,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: submitting ? null : widget.onHaveCode,
                    child: const Text('Ya tengo un código'),
                  ),
                  if (sent) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      'Si existe una cuenta con ese correo, te enviamos '
                      'instrucciones para restablecer la contraseña.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                  if (state is ForgotPasswordFailed) ...<Widget>[
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

  String _messageFor(ForgotPasswordFailureKind kind) => switch (kind) {
    ForgotPasswordFailureKind.rateLimited =>
      'Demasiados intentos, espera un momento',
    ForgotPasswordFailureKind.network => 'Sin conexión, reintenta',
    ForgotPasswordFailureKind.unknown => 'Algo salió mal, intenta de nuevo',
  };
}
