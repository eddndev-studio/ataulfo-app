import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../bloc/accept_invitation_cubit.dart';
import '../bloc/auth_bloc.dart';

/// Pantalla para canjear una invitación pendiente. Página content-only: la
/// ruta aporta Scaffold + AppBar.
///
/// La invitación se canjea con el operador YA logueado (el backend valida que
/// el correo de la sesión coincida con el invitado), así que la página se
/// gobierna por el estado de la sesión: sin sesión dirige a autenticarse;
/// con sesión muestra el formulario de pegado. Lee el `AuthBloc` con un
/// `BlocBuilder` (no un read de una sola vez) para renderizar también durante
/// el check inicial (`AuthInitial`) y transicionar en vivo cuando resuelve.
class AcceptInvitePage extends StatelessWidget {
  const AcceptInvitePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) => switch (auth) {
        AuthInitial() => const _LoadingView(),
        AuthUnauthenticated() => const _AuthPrompt(),
        AuthAuthenticated() || AuthAuthenticatedNoOrg() => _AcceptForm(
          // El destino tras aceptar depende del estado de sesión: con org
          // activa, /select-org rebota a /home, así que el Authenticated va a
          // /memberships; sin org activa va a /select-org. Ambas superficies
          // dejan activar la org recién unida.
          continueDestination: auth is AuthAuthenticatedNoOrg
              ? '/select-org'
              : '/memberships',
        ),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
}

/// Sin sesión: el canje exige estar logueado con el correo invitado. El token
/// pegado NO se arrastra a través del login/registro — la invitación abre el
/// SERVIDOR (o llega como texto), no hay deep-link que rellene el campo, y el
/// flujo natural es pasar el auth-gate y luego volver a pegar el código. Por
/// eso aquí sólo dirigimos a autenticarse, sin preservar lo escrito.
class _AuthPrompt extends StatelessWidget {
  const _AuthPrompt();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp6,
          vertical: AppTokens.sp7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Inicia sesión o crea una cuenta con el correo invitado para '
              'aceptar la invitación.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTokens.sp6),
            AppButton.filled(
              label: 'Iniciar sesión',
              fullWidth: true,
              onPressed: () => context.push('/login'),
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Crear cuenta',
              fullWidth: true,
              onPressed: () => context.push('/register'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulario de aceptación bajo sesión válida. Gobernado por el cubit:
/// Idle/Failed muestran el campo de pegado; Accepting bloquea con loading;
/// Accepted muestra el éxito in-page (no un SnackBar, que se tragaría al
/// desmontar la ruta tras navegar) con un botón para activar la org nueva.
class _AcceptForm extends StatefulWidget {
  const _AcceptForm({required this.continueDestination});

  /// Ruta a la que lleva "Continuar" tras aceptar: la superficie de switch
  /// donde el operador activa la membership recién creada.
  final String continueDestination;

  @override
  State<_AcceptForm> createState() => _AcceptFormState();
}

class _AcceptFormState extends State<_AcceptForm> {
  final TextEditingController _token = TextEditingController();

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<AcceptInvitationCubit>().accept(_token.text);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: BlocBuilder<AcceptInvitationCubit, AcceptInvitationState>(
        builder: (context, state) {
          if (state is AcceptInvitationAccepting) return const _LoadingView();
          if (state is AcceptInvitationAccepted) {
            return _SuccessView(destination: widget.continueDestination);
          }
          final failedKind = state is AcceptInvitationFailed
              ? state.kind
              : null;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              AppTokens.sp6,
              AppTokens.sp7,
              AppTokens.sp6,
              AppTokens.sp6 + context.safeBottomInset,
            ),
            children: <Widget>[
              Text(
                'Pega el enlace o el código de la invitación que recibiste para '
                'unirte a la organización.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: AppTokens.sp6),
              AppTextField(
                key: const Key('accept.token'),
                label: 'Enlace o código',
                hint: 'Pega aquí el enlace o el código',
                controller: _token,
                autocorrect: false,
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: AppTokens.sp6),
              AppButton.filled(
                label: 'Aceptar invitación',
                fullWidth: true,
                onPressed: _submit,
              ),
              if (failedKind != null) ...<Widget>[
                const SizedBox(height: AppTokens.sp4),
                Text(
                  _messageFor(failedKind),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTokens.danger),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _messageFor(AcceptInvitationFailureKind kind) => switch (kind) {
    AcceptInvitationFailureKind.invalidInput =>
      'Pega el código o enlace de la invitación',
    AcceptInvitationFailureKind.invalidToken =>
      'La invitación no es válida o ya expiró',
    AcceptInvitationFailureKind.emailMismatch =>
      'Esta invitación es para otro correo, o ya eres miembro de esa '
          'organización',
    AcceptInvitationFailureKind.network => 'Sin conexión, reintenta',
    AcceptInvitationFailureKind.unknown =>
      'No pudimos aceptar la invitación, reintenta',
  };
}

/// Éxito in-page tras aceptar. La membership existe pero no está activa; el
/// canje no flipa la sesión, así que "Continuar" lleva a la superficie de
/// switch para activarla. Es una vista in-page (no un SnackBar) porque navegar
/// desmonta esta ruta y un SnackBar cross-route se perdería.
class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.destination});

  final String destination;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.sp6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.check_circle_outline,
                color: AppTokens.success,
                size: 48,
              ),
              const SizedBox(height: AppTokens.sp4),
              Text(
                'Te uniste a la organización',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: AppTokens.sp6),
              AppButton.filled(
                label: 'Continuar',
                onPressed: () => context.go(destination),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
