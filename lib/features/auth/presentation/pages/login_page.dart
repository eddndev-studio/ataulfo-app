import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 32),
                  Text(
                    'Agentic',
                    style: Theme.of(context).textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  TextField(
                    key: const Key('login.email'),
                    controller: _email,
                    enabled: !submitting,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('login.password'),
                    controller: _password,
                    enabled: !submitting,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: submitting ? null : _submit,
                    child: submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 16),
                  if (state is LoginFailed)
                    Text(
                      _messageFor(state.kind),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
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
