import 'package:agentic/core/router/app_router.dart';
import 'package:agentic/features/auth/domain/entities/identity.dart';
import 'package:agentic/features/auth/domain/repositories/auth_repository.dart';
import 'package:agentic/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:agentic/features/auth/presentation/pages/login_page.dart';
import 'package:agentic/features/home/presentation/pages/home_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRepo extends Mock implements AuthRepository {}

const _identity = Identity(userId: 'u1', orgId: 'o1', role: 'OWNER');

Widget _host(AppRouter router, AuthBloc authBloc) =>
    BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: MaterialApp.router(routerConfig: router.router),
    );

void main() {
  late _MockAuthBloc authBloc;
  late AppRouter router;

  setUp(() {
    authBloc = _MockAuthBloc();
    router = AppRouter(authBloc: authBloc, repository: _MockRepo());
  });

  testWidgets('AuthInitial → Splash (CircularProgressIndicator)', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthInitial());

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AuthAuthenticated → redirige a HomePage', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('AuthUnauthenticated → redirige a LoginPage', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets(
    'cambio de estado dispara refreshListenable y re-evalúa redirect',
    (tester) async {
      // Stream que emite Unauthenticated → Authenticated. El router
      // arranca en Initial (Splash); tras Unauthenticated va a /login;
      // tras Authenticated, redirige a /home. Lo importante es que el
      // último estado mande — eso valida que el stream se está
      // consumiendo y el redirect re-evalúa.
      whenListen(
        authBloc,
        Stream<AuthState>.fromIterable(const <AuthState>[
          AuthUnauthenticated(),
          AuthAuthenticated(_identity),
        ]),
        initialState: const AuthInitial(),
      );

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    },
  );
}
