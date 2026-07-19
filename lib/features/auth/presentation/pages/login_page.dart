import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_text_action.dart';
import '../../domain/entities/auth_tokens.dart';
import '../bloc/login_bloc.dart';

/// Página de login. Es presentación pura: la lógica vive en `LoginBloc`.
///
/// `onSucceeded` es opcional para tests; en la app real lo cabla el router
/// (navegación post-login). El BlocListener garantiza que el callback se
/// invoca exactamente una vez por transición a `LoginSucceeded`.
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.onSucceeded,
    this.onCreateAccount,
    this.onForgotPassword,
    this.justReset = false,
  });

  final void Function(AuthTokens tokens)? onSucceeded;

  /// Navegación a la pantalla de alta de cuenta. Opcional para tests; en la
  /// app real lo cabla el router (empuja `/register`).
  final VoidCallback? onCreateAccount;

  /// Navegación al flujo de recuperación de contraseña. Opcional para tests;
  /// en la app real lo cabla el router (empuja `/forgot-password`).
  final VoidCallback? onForgotPassword;

  /// El operador acaba de restablecer su contraseña y aterrizó aquí (el reset
  /// revocó todas sus sesiones). Muestra un aviso para que sepa que el cambio
  /// surtió efecto y que debe entrar con la contraseña nueva. El router lo
  /// activa cuando la ruta llega con `?reset=success`.
  final bool justReset;

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
            // Scrolleable: cuando el teclado encoge el body, el contenido se
            // desplaza y el campo enfocado/botón quedan alcanzables.
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.sp6,
                vertical: AppTokens.sp7,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: AppTokens.sp7),
                  Text(
                    'Ataúlfo',
                    style: textTheme.displayLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (widget.justReset) ...<Widget>[
                    const SizedBox(height: AppTokens.sp6),
                    Text(
                      'Contraseña restablecida. Inicia sesión con la nueva.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTokens.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTokens.sp8),
                  AppTextField(
                    key: const Key('login.email'),
                    label: 'Email',
                    hint: 'tucorreo@dominio.com',
                    controller: _email,
                    enabled: !submitting,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                  ),
                  const SizedBox(height: AppTokens.sp4),
                  AppTextField(
                    key: const Key('login.password'),
                    label: 'Contraseña',
                    hint: 'Tu contraseña',
                    controller: _password,
                    enabled: !submitting,
                    obscureText: true,
                    obscureToggle: true,
                  ),
                  const SizedBox(height: AppTokens.sp6),
                  // El feedback de envío vive en el propio botón (loading
                  // bloquea el tap internamente, sin nullificar onPressed).
                  AppButton.filled(
                    label: 'Entrar',
                    fullWidth: true,
                    loading: submitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppTokens.sp2),
                  AppTextAction(
                    label: 'Crear cuenta',
                    onPressed: submitting ? null : widget.onCreateAccount,
                  ),
                  AppTextAction(
                    label: '¿Olvidaste tu contraseña?',
                    onPressed: submitting ? null : widget.onForgotPassword,
                  ),
                  const SizedBox(height: AppTokens.sp4),
                  if (state is LoginFailed)
                    Text(
                      _messageFor(state.kind),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTokens.danger,
                      ),
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
