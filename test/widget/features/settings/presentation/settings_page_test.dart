import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/settings/presentation/pages/settings_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _identity = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
);

const _admin = Identity(
  userId: 'u2',
  orgId: 'o1',
  role: 'ADMIN',
  email: 'admin@example.com',
);

const _supervisor = Identity(
  userId: 'u3',
  orgId: 'o1',
  role: 'SUPERVISOR',
  email: 'sup@example.com',
);

const _worker = Identity(
  userId: 'u4',
  orgId: 'o1',
  role: 'WORKER',
  email: 'worker@example.com',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const AuthLoggedOut());
  });

  late _MockAuthBloc authBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      // En el shell real, SettingsPage es content-only del Scaffold del
      // ShellPage. En aislamiento, lo envolvemos en Scaffold para que
      // los primitivos del DS tengan Material upstream.
      child: const Scaffold(body: SettingsPage()),
    ),
  );

  testWidgets(
    'Authenticated muestra email vivo + rol como AppPill + AppButton.danger',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

      await tester.pumpWidget(host());

      // Email vivo del backend (post-S02: /auth/me lo trae). Antes Settings
      // sólo exponía el rol porque el UUID era ruido; ahora el operador
      // ve quién está logueado.
      expect(find.text('op@example.com'), findsOneWidget);
      // Rol interpretado al humano (la jerga del wire no llega a la UI).
      expect(find.widgetWithText(AppPill, 'Propietario'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Cerrar sesión'), findsOneWidget);
      // UUIDs siguen sin mostrarse — el user_id/org_id NO entra a la UI.
      expect(find.text('u1'), findsNothing);
      expect(find.text('o1'), findsNothing);
      // Los M3 baseline ya no deben aparecer.
      expect(find.byType(Chip), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    },
  );

  testWidgets('Authenticated expone tile "Tus organizaciones"', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(host());

    // Key contractual para que el test de navegación lo localice sin
    // acoplarse al copy y para que smoke tests futuros lo encuentren
    // rápido en device.
    expect(find.byKey(const Key('settings.memberships_tile')), findsOneWidget);
    expect(find.text('Tus organizaciones'), findsOneWidget);
  });

  testWidgets('tap "Tus organizaciones" apila /memberships (push, no go)', (
    tester,
  ) async {
    // Mismo patrón que el test del tile de Templates/Bots: el destino
    // observa Navigator.canPop() para detectar si la fuente apiló
    // (push) o reemplazó la pila (go). go() saca al usuario de la app
    // con el back físico — guard contractual contra esa regresión.
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    final navigated = <String>[];
    final canPopAtDestination = <bool>[];
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const Scaffold(body: SettingsPage()),
          ),
        ),
        GoRoute(
          path: '/memberships',
          builder: (_, _) {
            navigated.add('/memberships');
            return Scaffold(
              body: Builder(
                builder: (ctx) {
                  canPopAtDestination.add(Navigator.of(ctx).canPop());
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(const Key('settings.memberships_tile')));
    await tester.pumpAndSettle();

    expect(navigated, <String>['/memberships']);
    expect(
      canPopAtDestination,
      <bool>[true],
      reason:
          'el listado de memberships debe quedar apilado sobre Settings '
          'para que el back físico vuelva al shell',
    );
  });

  testWidgets('Authenticated expone tile "Galería de multimedia"', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('settings.media_tile')), findsOneWidget);
    expect(find.text('Galería de multimedia'), findsOneWidget);
  });

  testWidgets('Authenticated expone tile "Notificaciones"', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('settings.notifications_tile')),
      findsOneWidget,
    );
    expect(find.text('Notificaciones'), findsOneWidget);
  });

  testWidgets('tap "Notificaciones" apila /notifications (push, no go)', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    final navigated = <String>[];
    final canPopAtDestination = <bool>[];
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const Scaffold(body: SettingsPage()),
          ),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) {
            navigated.add('/notifications');
            return Scaffold(
              body: Builder(
                builder: (ctx) {
                  canPopAtDestination.add(Navigator.of(ctx).canPop());
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(const Key('settings.notifications_tile')));
    await tester.pumpAndSettle();

    expect(navigated, <String>['/notifications']);
    expect(canPopAtDestination, <bool>[true]);
  });

  testWidgets('tap "Galería de multimedia" apila /media (push, no go)', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    final navigated = <String>[];
    final canPopAtDestination = <bool>[];
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const Scaffold(body: SettingsPage()),
          ),
        ),
        GoRoute(
          path: '/media',
          builder: (_, _) {
            navigated.add('/media');
            return Scaffold(
              body: Builder(
                builder: (ctx) {
                  canPopAtDestination.add(Navigator.of(ctx).canPop());
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(const Key('settings.media_tile')));
    await tester.pumpAndSettle();

    expect(navigated, <String>['/media']);
    expect(
      canPopAtDestination,
      <bool>[true],
      reason:
          'la galería debe quedar apilada sobre Settings para que el back '
          'físico vuelva al shell',
    );
  });

  testWidgets('OWNER ve el tile admin-gated "Miembros"', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('settings.members_tile')), findsOneWidget);
    expect(find.text('Miembros'), findsOneWidget);
  });

  testWidgets('ADMIN ve el tile admin-gated "Miembros"', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_admin));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('settings.members_tile')), findsOneWidget);
  });

  testWidgets('SUPERVISOR NO ve el tile "Miembros" (gate cosmético ADMIN+)', (
    tester,
  ) async {
    // SUPERVISOR queda por debajo de ADMIN: el backend lo 403ea, así que la
    // app no le ofrece el control. El gate es cosmético, no de seguridad.
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_supervisor));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('settings.members_tile')), findsNothing);
    expect(find.text('Miembros'), findsNothing);
  });

  testWidgets('WORKER NO ve el tile "Miembros"', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_worker));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('settings.members_tile')), findsNothing);
  });

  testWidgets('tap "Miembros" apila /members (push, no go)', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    final navigated = <String>[];
    final canPopAtDestination = <bool>[];
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const Scaffold(body: SettingsPage()),
          ),
        ),
        GoRoute(
          path: '/members',
          builder: (_, _) {
            navigated.add('/members');
            return Scaffold(
              body: Builder(
                builder: (ctx) {
                  canPopAtDestination.add(Navigator.of(ctx).canPop());
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(const Key('settings.members_tile')));
    await tester.pumpAndSettle();

    expect(navigated, <String>['/members']);
    expect(
      canPopAtDestination,
      <bool>[true],
      reason:
          'el listado de miembros debe quedar apilado sobre Settings para que '
          'el back físico vuelva al shell',
    );
  });

  testWidgets('Cerrar sesión pide confirmación antes de despachar el logout', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(AppButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    // El tap abre el diálogo; el logout NO se despacha todavía.
    expect(find.byType(AlertDialog), findsOneWidget);
    verifyNever(() => authBloc.add(const AuthLoggedOut()));

    await tester.tap(find.byKey(const Key('settings.logout_confirm')));
    await tester.pumpAndSettle();

    verify(() => authBloc.add(const AuthLoggedOut())).called(1);
  });

  testWidgets('Cancelar en la confirmación NO cierra la sesión', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(AppButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verifyNever(() => authBloc.add(const AuthLoggedOut()));
  });

  testWidgets('non-Authenticated renderiza vacío (trust router redirect)', (
    tester,
  ) async {
    // El redirect del router debería navegar fuera antes de que esto
    // sea visible más de un frame; mostramos nada en lugar de un
    // estado UI específico para evitar ruido en transiciones.
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

    await tester.pumpWidget(host());

    expect(find.text('OWNER'), findsNothing);
    expect(find.byType(AppButton), findsNothing);
    expect(find.byType(AppPill), findsNothing);
  });
}
