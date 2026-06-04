import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/accept_invitation_cubit.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/auth/presentation/pages/accept_invite_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockCubit extends MockCubit<AcceptInvitationState>
    implements AcceptInvitationCubit {}

const _withOrg = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@x.com',
);

const _noOrg = Identity(userId: 'u1', orgId: '', role: '', email: 'op@x.com');

void main() {
  late _MockAuthBloc auth;
  late _MockCubit cubit;

  setUp(() {
    auth = _MockAuthBloc();
    cubit = _MockCubit();
    when(() => cubit.state).thenReturn(const AcceptInvitationIdle());
    when(() => cubit.accept(any())).thenAnswer((_) async {});
  });

  // Router-backed host: la página usa context.push/context.go directamente
  // (sin callbacks inyectados), así que necesita un Navigator de GoRouter. Las
  // rutas destino son stubs que sólo identifican a dónde se navegó. La ruta
  // raíz aporta el Scaffold + AppBar que la página content-only espera.
  Widget host() {
    final router = GoRouter(
      initialLocation: '/accept-invite',
      routes: <RouteBase>[
        GoRoute(
          path: '/accept-invite',
          builder: (_, _) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<AuthBloc>.value(value: auth),
              BlocProvider<AcceptInvitationCubit>.value(value: cubit),
            ],
            child: Scaffold(
              appBar: AppBar(title: const Text('Aceptar invitación')),
              body: const AcceptInvitePage(),
            ),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('LOGIN_STUB')),
        ),
        GoRoute(
          path: '/register',
          builder: (_, _) => const Scaffold(body: Text('REGISTER_STUB')),
        ),
        GoRoute(
          path: '/select-org',
          builder: (_, _) => const Scaffold(body: Text('SELECT_ORG_STUB')),
        ),
        GoRoute(
          path: '/memberships',
          builder: (_, _) => const Scaffold(body: Text('MEMBERSHIPS_STUB')),
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppDesignTheme.dark(),
      routerConfig: router,
    );
  }

  group('AcceptInvitePage — sesión', () {
    testWidgets(
      'AuthInitial muestra spinner (el check inicial está en vuelo)',
      (tester) async {
        when(() => auth.state).thenReturn(const AuthInitial());

        await tester.pumpWidget(host());
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('AuthUnauthenticated muestra el prompt de autenticación', (
      tester,
    ) async {
      when(() => auth.state).thenReturn(const AuthUnauthenticated());

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Inicia sesión o crea una cuenta'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, 'Iniciar sesión'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Crear cuenta'), findsOneWidget);
    });

    testWidgets('botón Iniciar sesión navega a /login', (tester) async {
      when(() => auth.state).thenReturn(const AuthUnauthenticated());

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN_STUB'), findsOneWidget);
    });

    testWidgets('botón Crear cuenta navega a /register', (tester) async {
      when(() => auth.state).thenReturn(const AuthUnauthenticated());

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('REGISTER_STUB'), findsOneWidget);
    });

    testWidgets(
      'transición EN VIVO Unauthenticated → Authenticated muestra el formulario',
      (tester) async {
        // La página renderiza bajo CUALQUIER estado y debe reaccionar cuando el
        // check resuelve, sin un context.read de una sola vez.
        whenListen(
          auth,
          Stream<AuthState>.fromIterable(const <AuthState>[
            AuthAuthenticated(_withOrg),
          ]),
          initialState: const AuthUnauthenticated(),
        );

        await tester.pumpWidget(host());
        await tester.pumpAndSettle();
        // Bajo sesión válida aparece el campo de pegado y el botón de aceptar.
        expect(find.byKey(const Key('accept.token')), findsOneWidget);
        expect(
          find.widgetWithText(AppButton, 'Aceptar invitación'),
          findsOneWidget,
        );
      },
    );
  });

  group('AcceptInvitePage — formulario (sesión con org)', () {
    testWidgets('Idle muestra el campo de pegado y el botón de aceptar', (
      tester,
    ) async {
      when(() => auth.state).thenReturn(const AuthAuthenticated(_withOrg));

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('accept.token')), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, 'Aceptar invitación'),
        findsOneWidget,
      );
    });

    testWidgets('pegar + enviar dispara accept con el texto pegado', (
      tester,
    ) async {
      when(() => auth.state).thenReturn(const AuthAuthenticated(_withOrg));

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('accept.token')), 'tok123');
      await tester.tap(find.widgetWithText(AppButton, 'Aceptar invitación'));
      await tester.pump();

      verify(() => cubit.accept('tok123')).called(1);
    });

    testWidgets('Accepting muestra loading', (tester) async {
      when(() => auth.state).thenReturn(const AuthAuthenticated(_withOrg));
      when(() => cubit.state).thenReturn(const AcceptInvitationAccepting());

      await tester.pumpWidget(host());
      // El spinner anima sin parar; pump() (no pumpAndSettle) evita el timeout.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AcceptInvitePage — éxito in-page', () {
    testWidgets('Accepted muestra el copy de éxito y el botón Continuar', (
      tester,
    ) async {
      when(() => auth.state).thenReturn(const AuthAuthenticated(_withOrg));
      when(() => cubit.state).thenReturn(const AcceptInvitationAccepted());

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('Te uniste a la organización'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Continuar'), findsOneWidget);
    });

    testWidgets('Accepted + Authenticated: Continuar navega a /memberships', (
      tester,
    ) async {
      // Bajo sesión con org activa, /select-org rebota a /home; por eso el
      // Authenticated va a /memberships, donde puede activar la org nueva.
      when(() => auth.state).thenReturn(const AuthAuthenticated(_withOrg));
      when(() => cubit.state).thenReturn(const AcceptInvitationAccepted());

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('MEMBERSHIPS_STUB'), findsOneWidget);
    });

    testWidgets('Accepted + NoOrg: Continuar navega a /select-org', (
      tester,
    ) async {
      when(() => auth.state).thenReturn(const AuthAuthenticatedNoOrg(_noOrg));
      when(() => cubit.state).thenReturn(const AcceptInvitationAccepted());

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('SELECT_ORG_STUB'), findsOneWidget);
    });
  });

  group('AcceptInvitePage — fallos con copy por kind', () {
    Future<void> pumpFailed(
      WidgetTester tester,
      AcceptInvitationFailureKind kind,
    ) async {
      when(() => auth.state).thenReturn(const AuthAuthenticated(_withOrg));
      when(() => cubit.state).thenReturn(AcceptInvitationFailed(kind));
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
    }

    testWidgets('invalidInput', (tester) async {
      await pumpFailed(tester, AcceptInvitationFailureKind.invalidInput);
      expect(
        find.text('Pega el código o enlace de la invitación'),
        findsOneWidget,
      );
    });

    testWidgets('invalidToken', (tester) async {
      await pumpFailed(tester, AcceptInvitationFailureKind.invalidToken);
      expect(
        find.text('La invitación no es válida o ya expiró'),
        findsOneWidget,
      );
    });

    testWidgets('emailMismatch', (tester) async {
      await pumpFailed(tester, AcceptInvitationFailureKind.emailMismatch);
      expect(
        find.text(
          'Esta invitación es para otro correo, o ya eres miembro de esa '
          'organización',
        ),
        findsOneWidget,
      );
    });

    testWidgets('network', (tester) async {
      await pumpFailed(tester, AcceptInvitationFailureKind.network);
      expect(find.text('Sin conexión, reintenta'), findsOneWidget);
    });

    testWidgets('unknown', (tester) async {
      await pumpFailed(tester, AcceptInvitationFailureKind.unknown);
      expect(
        find.text('No pudimos aceptar la invitación, reintenta'),
        findsOneWidget,
      );
    });

    testWidgets('Failed conserva el campo de pegado y permite reintentar', (
      tester,
    ) async {
      await pumpFailed(tester, AcceptInvitationFailureKind.network);
      // El campo sigue presente para reintentar sin re-navegar.
      expect(find.byKey(const Key('accept.token')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('accept.token')), 'retry');
      await tester.tap(find.widgetWithText(AppButton, 'Aceptar invitación'));
      await tester.pump();
      verify(() => cubit.accept('retry')).called(1);
    });
  });
}
