import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/features/auth/domain/entities/auth_tokens.dart';
import 'package:ataulfo/features/auth/presentation/bloc/register_bloc.dart';
import 'package:ataulfo/features/auth/presentation/pages/register_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRegisterBloc extends MockBloc<RegisterEvent, RegisterState>
    implements RegisterBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const RegisterSubmitted(email: '', password: '', confirmPassword: ''),
    );
  });

  late _MockRegisterBloc bloc;

  setUp(() {
    bloc = _MockRegisterBloc();
    when(() => bloc.state).thenReturn(const RegisterInitial());
  });

  Widget host({
    void Function(AuthTokens)? onSucceeded,
    VoidCallback? onGoToLogin,
  }) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<RegisterBloc>.value(
      value: bloc,
      child: RegisterPage(onSucceeded: onSucceeded, onGoToLogin: onGoToLogin),
    ),
  );

  testWidgets('renderiza email + password + confirm + AppButton Crear cuenta', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('register.email')), findsOneWidget);
    expect(find.byKey(const Key('register.password')), findsOneWidget);
    expect(find.byKey(const Key('register.confirmPassword')), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Crear cuenta'), findsOneWidget);
    // Los tres campos pasan al primitivo del DS.
    expect(find.byType(AppTextField), findsNWidgets(3));
  });

  testWidgets('los dos campos de contraseña llevan obscureToggle', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    final pw = tester.widget<AppTextField>(
      find.byKey(const Key('register.password')),
    );
    final confirm = tester.widget<AppTextField>(
      find.byKey(const Key('register.confirmPassword')),
    );
    expect(pw.obscureText, isTrue);
    expect(pw.obscureToggle, isTrue);
    expect(confirm.obscureText, isTrue);
    expect(confirm.obscureToggle, isTrue);
  });

  testWidgets('botón deshabilitado hasta que los tres campos tengan texto', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    AppButton button() => tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Crear cuenta'),
    );

    // Sin texto: deshabilitado (onPressed null).
    expect(button().onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('register.email')),
      'op@example.com',
    );
    await tester.pump();
    expect(button().onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('register.password')),
      'hunter2-secret',
    );
    await tester.pump();
    expect(button().onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('register.confirmPassword')),
      'hunter2-secret',
    );
    await tester.pump();
    // Los tres con texto: habilitado. La validación fina (longitud,
    // coincidencia) la hace el bloc; el gate del botón sólo exige no-vacío.
    expect(button().onPressed, isNotNull);
  });

  testWidgets('submit dispara RegisterSubmitted con los tres valores', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.enterText(
      find.byKey(const Key('register.email')),
      'op@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register.password')),
      'hunter2-secret',
    );
    await tester.enterText(
      find.byKey(const Key('register.confirmPassword')),
      'hunter2-secret',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(AppButton, 'Crear cuenta'));
    await tester.pump();

    verify(
      () => bloc.add(
        const RegisterSubmitted(
          email: 'op@example.com',
          password: 'hunter2-secret',
          confirmPassword: 'hunter2-secret',
        ),
      ),
    ).called(1);
  });

  testWidgets('estado Submitting muestra CircularProgressIndicator', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<RegisterState>.fromIterable(const <RegisterState>[
        RegisterSubmitting(),
      ]),
      initialState: const RegisterSubmitting(),
    );

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('estado Failed(passwordMismatch) muestra mensaje específico', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<RegisterState>.fromIterable(const <RegisterState>[
        RegisterFailed(RegisterFailureKind.passwordMismatch),
      ]),
      initialState: const RegisterInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });

  testWidgets('estado Failed(emailTaken) muestra mensaje específico', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<RegisterState>.fromIterable(const <RegisterState>[
        RegisterFailed(RegisterFailureKind.emailTaken),
      ]),
      initialState: const RegisterInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('Ese correo ya tiene una cuenta'), findsOneWidget);
  });

  testWidgets('estado Failed pinta el mensaje en AppTokens.danger', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<RegisterState>.fromIterable(const <RegisterState>[
        RegisterFailed(RegisterFailureKind.unknown),
      ]),
      initialState: const RegisterInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    final t = tester.widget<Text>(
      find.text('Algo salió mal, intenta de nuevo'),
    );
    expect(t.style?.color, AppTokens.danger);
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
      Stream<RegisterState>.fromIterable(const <RegisterState>[
        RegisterSucceeded(tokens),
      ]),
      initialState: const RegisterInitial(),
    );

    AuthTokens? captured;
    await tester.pumpWidget(host(onSucceeded: (t) => captured = t));
    await tester.pump();

    expect(captured, tokens);
  });

  testWidgets('"Ya tengo cuenta" invoca onGoToLogin', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(onGoToLogin: () => tapped = true));

    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
