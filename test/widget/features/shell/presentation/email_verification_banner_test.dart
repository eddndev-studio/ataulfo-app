import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/auth/presentation/bloc/resend_verification_cubit.dart';
import 'package:ataulfo/features/shell/presentation/widgets/email_verification_banner.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockResendCubit extends MockBloc<Object, ResendVerificationState>
    implements ResendVerificationCubit {}

const _unverified = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
);

const _verified = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
  emailVerified: true,
);

void main() {
  late _MockAuthBloc authBloc;
  late _MockResendCubit resendCubit;

  setUp(() {
    authBloc = _MockAuthBloc();
    resendCubit = _MockResendCubit();
    when(() => resendCubit.state).thenReturn(const ResendVerificationIdle());
  });

  // Un router para resolver la navegación de "Verificar" sin montar todo el
  // AppRouter: la home pinta el banner, /verify-email es un destino tonto que
  // sólo registra que se navegó a él.
  final navigated = <String>[];

  Widget host() {
    navigated.clear();
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<ResendVerificationCubit>.value(value: resendCubit),
            ],
            child: const Scaffold(
              body: EmailVerificationBanner(child: SizedBox.shrink()),
            ),
          ),
        ),
        GoRoute(
          path: '/verify-email',
          builder: (_, state) {
            navigated.add(state.uri.toString());
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppDesignTheme.dark(),
      routerConfig: router,
    );
  }

  testWidgets('autenticado + email NO verificado: el aviso es visible', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_unverified));

    await tester.pumpWidget(host());

    expect(find.text('Verifica tu correo'), findsOneWidget);
    expect(find.text('Reenviar'), findsOneWidget);
    expect(find.text('Verificar'), findsOneWidget);
  });

  testWidgets('autenticado + email verificado: el aviso está ausente', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_verified));

    await tester.pumpWidget(host());

    expect(find.text('Verifica tu correo'), findsNothing);
    expect(find.text('Reenviar'), findsNothing);
  });

  testWidgets('Reenviar dispara resend() del cubit', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_unverified));
    when(() => resendCubit.resend()).thenAnswer((_) async {});

    await tester.pumpWidget(host());
    await tester.tap(find.text('Reenviar'));
    await tester.pump();

    verify(() => resendCubit.resend()).called(1);
  });

  testWidgets('Sending: Reenviar muestra loading y bloquea re-taps', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_unverified));
    when(() => resendCubit.state).thenReturn(const ResendVerificationSending());
    when(() => resendCubit.resend()).thenAnswer((_) async {});

    await tester.pumpWidget(host());

    // El botón comunica el envío en curso (spinner inline del AppButton)…
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // …y bloquea el tap mientras tanto: nada de reenvíos en ráfaga.
    final resendBtn = find.byWidgetPredicate(
      (w) => w is AppButton && w.label == 'Reenviar',
    );
    await tester.tap(resendBtn);
    await tester.pump();

    verifyNever(() => resendCubit.resend());
  });

  testWidgets('Sent muestra el SnackBar de reenvío', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_unverified));
    whenListen(
      resendCubit,
      Stream<ResendVerificationState>.fromIterable(
        const <ResendVerificationState>[ResendVerificationSent()],
      ),
      initialState: const ResendVerificationIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('Te reenviamos el correo'), findsOneWidget);
  });

  testWidgets('Failed muestra un SnackBar de error', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_unverified));
    whenListen(
      resendCubit,
      Stream<ResendVerificationState>.fromIterable(
        const <ResendVerificationState>[ResendVerificationFailed()],
      ),
      initialState: const ResendVerificationIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(
      find.text('No pudimos reenviar el correo, reintenta'),
      findsOneWidget,
    );
    expect(find.text('Te reenviamos el correo'), findsNothing);
  });

  testWidgets('el aviso consume el inset del status bar (no queda debajo)', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_unverified));

    const inset = 24.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: inset)),
          child: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<ResendVerificationCubit>.value(value: resendCubit),
            ],
            child: const Scaffold(
              body: EmailVerificationBanner(child: SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Verifica tu correo')).dy,
      greaterThanOrEqualTo(inset),
      reason:
          'con la sesión online el aviso es lo primero de la pantalla: '
          'debe reservar el inset, no pintarse bajo el status bar',
    );
  });

  testWidgets('Verificar navega a /verify-email con el correo de la sesión', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_unverified));

    await tester.pumpWidget(host());
    await tester.tap(find.text('Verificar'));
    await tester.pumpAndSettle();

    expect(navigated, <String>['/verify-email?email=op%40example.com']);
  });
}
