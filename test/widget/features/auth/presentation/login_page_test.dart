import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/features/auth/domain/entities/auth_tokens.dart';
import 'package:ataulfo/features/auth/presentation/bloc/login_bloc.dart';
import 'package:ataulfo/features/auth/presentation/pages/login_page.dart';
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

  Widget host({
    void Function(AuthTokens)? onSucceeded,
    VoidCallback? onCreateAccount,
  }) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<LoginBloc>.value(
      value: bloc,
      child: LoginPage(
        onSucceeded: onSucceeded,
        onCreateAccount: onCreateAccount,
      ),
    ),
  );

  testWidgets('renderiza campos email + password + AppButton Entrar', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('login.email')), findsOneWidget);
    expect(find.byKey(const Key('login.password')), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Entrar'), findsOneWidget);
    // Los dos campos pasan al primitivo del DS.
    expect(find.byType(AppTextField), findsNWidgets(2));
    // El botón del login pasa al primitivo del DS — el FilledButton M3
    // legado no debe quedar en el árbol.
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('wordmark "Ataúlfo" usa displayLarge del textTheme', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    final word = tester.widget<Text>(find.text('Ataúlfo'));
    expect(word.style?.fontSize, AppTokens.displaySize);
    expect(word.style?.fontWeight, AppTokens.displayWeight);
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
    await tester.tap(find.widgetWithText(AppButton, 'Entrar'));
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
    await tester.pumpWidget(host(onSucceeded: (t) => captured = t));
    await tester.pump();

    expect(captured, tokens);
  });

  testWidgets('estado Failed pinta el mensaje en AppTokens.danger', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<LoginState>.fromIterable(const <LoginState>[
        LoginFailed(LoginFailureKind.unknown),
      ]),
      initialState: const LoginInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    final t = tester.widget<Text>(
      find.text('Algo salió mal, intenta de nuevo'),
    );
    expect(t.style?.color, AppTokens.danger);
  });

  testWidgets('"Crear cuenta" invoca onCreateAccount', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(onCreateAccount: () => tapped = true));

    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
