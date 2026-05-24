import 'package:agentic/features/auth/domain/entities/auth_tokens.dart';
import 'package:agentic/features/auth/presentation/bloc/login_bloc.dart';
import 'package:agentic/features/auth/presentation/pages/login_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoginBloc extends MockBloc<LoginEvent, LoginState>
    implements LoginBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const LoginSubmitted(email: '', password: ''));
  });

  late _MockLoginBloc bloc;

  setUp(() {
    bloc = _MockLoginBloc();
    when(() => bloc.state).thenReturn(const LoginInitial());
  });

  Widget host() => MaterialApp(
    home: BlocProvider<LoginBloc>.value(value: bloc, child: const LoginPage()),
  );

  testWidgets('renderiza campos email + password + botón Entrar', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('login.email')), findsOneWidget);
    expect(find.byKey(const Key('login.password')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
  });

  testWidgets('submit con datos válidos dispara LoginSubmitted', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.enterText(
      find.byKey(const Key('login.email')),
      'op@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login.password')),
      'hunter2-secret',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();

    verify(
      () => bloc.add(
        const LoginSubmitted(
          email: 'op@example.com',
          password: 'hunter2-secret',
        ),
      ),
    ).called(1);
  });

  testWidgets('estado Submitting muestra CircularProgressIndicator', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<LoginState>.fromIterable(const <LoginState>[LoginSubmitting()]),
      initialState: const LoginSubmitting(),
    );

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('estado Failed(invalidCredentials) muestra mensaje específico', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<LoginState>.fromIterable(const <LoginState>[
        LoginFailed(LoginFailureKind.invalidCredentials),
      ]),
      initialState: const LoginInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('Credenciales inválidas'), findsOneWidget);
  });

  testWidgets('estado Failed(network) muestra mensaje de red', (tester) async {
    whenListen(
      bloc,
      Stream<LoginState>.fromIterable(const <LoginState>[
        LoginFailed(LoginFailureKind.network),
      ]),
      initialState: const LoginInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('Sin conexión, reintenta'), findsOneWidget);
  });

  testWidgets('estado Succeeded notifica al callback onSucceeded', (
    tester,
  ) async {
    const tokens = AuthTokens(
      accessToken: 'a',
      refreshToken: 'r',
      tokenType: 'Bearer',
      expiresInSeconds: 900,
    );
    whenListen(
      bloc,
      Stream<LoginState>.fromIterable(const <LoginState>[
        LoginSucceeded(tokens),
      ]),
      initialState: const LoginInitial(),
    );

    AuthTokens? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<LoginBloc>.value(
          value: bloc,
          child: LoginPage(onSucceeded: (t) => captured = t),
        ),
      ),
    );
    await tester.pump();

    expect(captured, tokens);
  });
}
