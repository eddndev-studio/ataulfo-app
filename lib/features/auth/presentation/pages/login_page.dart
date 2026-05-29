import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/auth_tokens.dart';
import '../bloc/login_bloc.dart';

/// Página de login. Es presentación pura: la lógica vive en `LoginBloc`.
///
/// `onSucceeded` es opcional para tests; en la app real lo cabla el router
/// (navegación post-login). El BlocListener garantiza que el callback se
/// invoca exactamente una vez por transición a `LoginSucceeded`.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onSucceeded});

  final void Function(AuthTokens tokens)? onSucceeded;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<LoginBloc>().add(
      LoginSubmitted(email: _email.text, password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<LoginBloc, LoginState>(
          listener: (context, state) {
            if (state is LoginSucceeded) {
              widget.onSucceeded?.call(state.tokens);
            }
          },
          builder: (context, state) {
            final submitting = state is LoginSubmitting;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 32),
                  Text(
                    'Agentic',
                    style: textTheme.displayLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  AppTextField(
                    key: const Key('login.email'),
                    label: 'Email',
                    hint: 'tucorreo@dominio.com',
                    controller: _email,
                    enabled: !submitting,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    key: const Key('login.password'),
                    label: 'Contraseña',
                    hint: 'Tu contraseña',
                    controller: _password,
                    enabled: !submitting,
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  AppButton.filled(
                    label: 'Entrar',
                    fullWidth: true,
                    onPressed: submitting ? null : _submit,
                  ),
                  const SizedBox(height: 16),
                  if (submitting)
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTokens.primary,
                          ),
                        ),
                      ),
                    ),
                  if (state is LoginFailed)
                    Text(
                      _messageFor(state.kind),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTokens.danger),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _messageFor(LoginFailureKind kind) => switch (kind) {
    LoginFailureKind.invalidInput => 'Completa email y contraseña',
    LoginFailureKind.invalidCredentials => 'Credenciales inválidas',
    LoginFailureKind.rateLimited => 'Demasiados intentos, espera un momento',
    LoginFailureKind.network => 'Sin conexión, reintenta',
    LoginFailureKind.unknown => 'Algo salió mal, intenta de nuevo',
  };
}
