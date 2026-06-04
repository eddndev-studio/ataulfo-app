import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/auth/presentation/bloc/verify_email_bloc.dart';
import 'package:ataulfo/features/auth/presentation/pages/verify_email_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRepo extends Mock implements AuthRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AuthCheckRequested());
  });

  late _MockAuthBloc authBloc;
  late _MockRepo repo;

  setUp(() {
    authBloc = _MockAuthBloc();
    repo = _MockRepo();
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());
  });

  // Réplica mínima del cableado del AppRouter para /verify-email: el page se
  // monta con su bloc real sobre el repo, y onSucceeded refresca la sesión
  // (AuthCheckRequested) y vuelve atrás (aquí: a /home porque no hay pila).
  Widget host() {
    final router = GoRouter(
      initialLocation: '/verify-email',
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/verify-email',
          builder: (context, _) => BlocProvider<VerifyEmailBloc>(
            create: (_) => VerifyEmailBloc(repo),
            child: VerifyEmailPage(
              onSucceeded: ({required bool alreadyVerified}) {
                authBloc.add(const AuthCheckRequested());
                context.canPop() ? context.pop() : context.go('/home');
              },
            ),
          ),
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppDesignTheme.dark(),
      routerConfig: router,
    );
  }

  testWidgets('/verify-email renderiza la VerifyEmailPage', (tester) async {
    await tester.pumpWidget(host());

    expect(find.byType(VerifyEmailPage), findsOneWidget);
  });

  testWidgets(
    'canje exitoso refresca la sesión (AuthCheckRequested) y navega a /home',
    (tester) async {
      when(() => repo.verifyEmail('tok123')).thenAnswer((_) async => false);

      await tester.pumpWidget(host());
      await tester.enterText(find.byType(TextField), 'tok123');
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      verify(() => authBloc.add(const AuthCheckRequested())).called(1);
      expect(find.text('home'), findsOneWidget);
    },
  );
}
