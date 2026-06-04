import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../bloc/verify_email_bloc.dart';

/// Página de verificación de correo. Es presentación pura: la lógica vive en
/// `VerifyEmailBloc`.
///
/// El correo de verificación abre el SERVIDOR, no la app; el operador pega aquí
/// el enlace completo o el token suelto. El bloc extrae el token y lo canjea.
/// `onSucceeded` es opcional para tests; en la app real lo cabla el router
/// (refresca la identidad de la sesión para que el aviso se resuelva y vuelve
/// atrás). El BlocListener garantiza que el callback se invoca exactamente una
/// vez por transición a Succeeded; el flag `alreadyVerified` distingue el
/// re-click idempotente (la cuenta ya estaba verificada) del éxito recién hecho
/// — sólo este último muestra un SnackBar de confirmación.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key, this.onSucceeded});

  final void Function({required bool alreadyVerified})? onSucceeded;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final TextEditingController _token = TextEditingController();

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<VerifyEmailBloc>().add(VerifyEmailSubmitted(_token.text));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar correo')),
      body: SafeArea(
        child: BlocConsumer<VerifyEmailBloc, VerifyEmailState>(
          listener: (context, state) {
            if (state is VerifyEmailSucceeded) {
              // Sólo la verificación recién hecha merece un aviso; un re-click
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
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 16),
                  Text(
                    'Pega el enlace o el código que te enviamos por correo para '
                    'verificar tu cuenta.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    key: const Key('verify.token'),
                    label: 'Enlace o código',
                    hint: 'Pega aquí el enlace del correo',
                    controller: _token,
                    enabled: !submitting,
                    autocorrect: false,
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),
                  AppButton.filled(
                    label: 'Verificar correo',
                    fullWidth: true,
                    loading: submitting,
                    onPressed: submitting ? null : _submit,
                  ),
                  if (state is VerifyEmailSucceeded) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      state.alreadyVerified
                          ? 'Tu correo ya estaba verificado'
                          : 'Correo verificado',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
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
      'Pega el enlace o el código que recibiste por correo',
    VerifyEmailFailureKind.invalidLink =>
      'El enlace no es válido. Solicita uno nuevo.',
    VerifyEmailFailureKind.expiredLink =>
      'El enlace caducó. Solicita uno nuevo.',
    VerifyEmailFailureKind.network => 'Sin conexión, reintenta',
    VerifyEmailFailureKind.unknown => 'Algo salió mal, intenta de nuevo',
  };
}
