import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../bloc/reset_password_bloc.dart';

/// Página de restablecimiento de contraseña. Es presentación pura: la lógica
/// vive en `ResetPasswordBloc`.
///
/// El correo de reset abre el SERVIDOR, no la app; el operador pega aquí el
/// enlace completo o el token suelto. El bloc extrae el token y valida la
/// longitud antes de canjear. `onSucceeded` es opcional para tests; en la app
/// real lo cabla el router (cierra la sesión local —el backend ya revocó las
/// familias de refresh— y rutea al login). El BlocListener garantiza que el
/// callback se invoca exactamente una vez por transición a Succeeded.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, this.onSucceeded});

  final VoidCallback? onSucceeded;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _token = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<ResetPasswordBloc>().add(
      ResetPasswordSubmitted(
        pastedLinkOrToken: _token.text,
        newPassword: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva contraseña')),
      body: SafeArea(
        child: BlocConsumer<ResetPasswordBloc, ResetPasswordState>(
          listener: (context, state) {
            if (state is ResetPasswordSucceeded) {
              widget.onSucceeded?.call();
            }
          },
          builder: (context, state) {
            final submitting = state is ResetPasswordSubmitting;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 16),
                  Text(
                    'Pega el enlace o el código que te enviamos por correo y '
                    'elige una contraseña nueva.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    key: const Key('reset.token'),
                    label: 'Enlace o código',
                    hint: 'Pega aquí el enlace del correo',
                    controller: _token,
                    enabled: !submitting,
                    autocorrect: false,
                    minLines: 2,
                    maxLines: 4,
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
                    label: 'Restablecer contraseña',
                    fullWidth: true,
                    loading: submitting,
                    onPressed: submitting ? null : _submit,
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
    );
  }

  String _messageFor(ResetPasswordFailureKind kind) => switch (kind) {
    ResetPasswordFailureKind.invalidInput =>
      'Pega el enlace o el código que recibiste por correo',
    ResetPasswordFailureKind.passwordTooShort =>
      'La contraseña debe tener al menos 12 caracteres',
    ResetPasswordFailureKind.invalidLink =>
      'El enlace no es válido. Solicita uno nuevo.',
    ResetPasswordFailureKind.expiredLink =>
      'El enlace caducó. Solicita uno nuevo.',
    ResetPasswordFailureKind.network => 'Sin conexión, reintenta',
    ResetPasswordFailureKind.unknown => 'Algo salió mal, intenta de nuevo',
  };
}
