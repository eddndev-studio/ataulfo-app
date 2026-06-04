import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/auth_tokens.dart';
import '../bloc/register_bloc.dart';

/// Página de alta de cuenta. Es presentación pura: la lógica vive en
/// `RegisterBloc`.
///
/// `onSucceeded` y `onGoToLogin` son opcionales para tests; en la app real los
/// cabla el router (navegación post-alta y vuelta al login). El BlocListener
/// garantiza que `onSucceeded` se invoca exactamente una vez por transición a
/// `RegisterSucceeded`.
///
/// El botón se habilita sólo cuando los tres campos tienen texto; la
/// validación fina (longitud, coincidencia) es responsabilidad del bloc, que
/// es la única autoridad de validación. Por eso la página escucha los
/// controllers (no LoginPage, que sólo exige dos campos y delega todo el gate
/// al bloc): el gate de no-vacío necesita rebuild en cada tecla.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.onSucceeded, this.onGoToLogin});

  final void Function(AuthTokens tokens)? onSucceeded;
  final VoidCallback? onGoToLogin;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _email.addListener(_onChanged);
    _password.addListener(_onChanged);
    _confirm.addListener(_onChanged);
  }

  @override
  void dispose() {
    _email.removeListener(_onChanged);
    _password.removeListener(_onChanged);
    _confirm.removeListener(_onChanged);
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  // Rebuild para re-evaluar el gate del botón cuando cambia cualquier campo.
  void _onChanged() => setState(() {});

  // El gate del botón exige sólo que los tres campos tengan texto; la
  // validación fina (longitud<12, coincidencia) la decide el bloc para no
  // duplicar la autoridad ni volver inalcanzables sus estados de error.
  bool get _canSubmit =>
      _email.text.isNotEmpty &&
      _password.text.isNotEmpty &&
      _confirm.text.isNotEmpty;

  void _submit() {
    context.read<RegisterBloc>().add(
      RegisterSubmitted(
        email: _email.text,
        password: _password.text,
        confirmPassword: _confirm.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<RegisterBloc, RegisterState>(
          listener: (context, state) {
            if (state is RegisterSucceeded) {
              widget.onSucceeded?.call(state.tokens);
            }
          },
          builder: (context, state) {
            final submitting = state is RegisterSubmitting;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 32),
                  Text(
                    'Ataúlfo',
                    style: textTheme.displayLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  AppTextField(
                    key: const Key('register.email'),
                    label: 'Email',
                    hint: 'tucorreo@dominio.com',
                    controller: _email,
                    enabled: !submitting,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    key: const Key('register.password'),
                    label: 'Contraseña',
                    hint: 'Mínimo 12 caracteres',
                    controller: _password,
                    enabled: !submitting,
                    obscureText: true,
                    obscureToggle: true,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    key: const Key('register.confirmPassword'),
                    label: 'Confirmar contraseña',
                    hint: 'Repite tu contraseña',
                    controller: _confirm,
                    enabled: !submitting,
                    obscureText: true,
                    obscureToggle: true,
                  ),
                  const SizedBox(height: 24),
                  AppButton.filled(
                    label: 'Crear cuenta',
                    fullWidth: true,
                    loading: submitting,
                    onPressed: (_canSubmit && !submitting) ? _submit : null,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: submitting ? null : widget.onGoToLogin,
                    child: const Text('Ya tengo cuenta'),
                  ),
                  if (state is RegisterFailed)
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

  String _messageFor(RegisterFailureKind kind) => switch (kind) {
    RegisterFailureKind.invalidInput => 'Completa todos los campos',
    RegisterFailureKind.passwordTooShort =>
      'La contraseña debe tener al menos 12 caracteres',
    RegisterFailureKind.passwordMismatch => 'Las contraseñas no coinciden',
    RegisterFailureKind.emailTaken => 'Ese correo ya tiene una cuenta',
    RegisterFailureKind.rateLimited =>
      'Demasiados intentos, espera un momento',
    RegisterFailureKind.network => 'Sin conexión, reintenta',
    RegisterFailureKind.unknown => 'Algo salió mal, intenta de nuevo',
  };
}
