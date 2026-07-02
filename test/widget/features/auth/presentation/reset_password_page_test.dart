import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_code_field.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/features/auth/presentation/bloc/forgot_password_bloc.dart';
import 'package:ataulfo/features/auth/presentation/bloc/reset_password_bloc.dart';
import 'package:ataulfo/features/auth/presentation/pages/reset_password_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockResetBloc extends MockBloc<ResetPasswordEvent, ResetPasswordState>
    implements ResetPasswordBloc {}

class _MockForgotBloc extends MockBloc<ForgotPasswordEvent, ForgotPasswordState>
    implements ForgotPasswordBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const ResetPasswordSubmitted(email: '', code: '', newPassword: ''),
    );
    registerFallbackValue(const ForgotPasswordSubmitted(email: ''));
  });

  late _MockResetBloc bloc;
  late _MockForgotBloc forgot;

  setUp(() {
    bloc = _MockResetBloc();
    forgot = _MockForgotBloc();
    when(() => bloc.state).thenReturn(const ResetPasswordInitial());
    when(() => forgot.state).thenReturn(const ForgotPasswordInitial());
  });

  Widget host({String initialEmail = '', VoidCallback? onSucceeded}) =>
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<ResetPasswordBloc>.value(value: bloc),
            BlocProvider<ForgotPasswordBloc>.value(value: forgot),
          ],
          child: ResetPasswordPage(
            initialEmail: initialEmail,
            onSucceeded: onSucceeded,
          ),
        ),
      );

  testWidgets('renderiza email + código + contraseña + botón + reenviar', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('reset.email')), findsOneWidget);
    expect(find.byKey(const Key('reset.code')), findsOneWidget);
    expect(find.byKey(const Key('reset.password')), findsOneWidget);
    expect(find.byKey(const Key('reset.resend')), findsOneWidget);
    expect(find.byType(AppCodeField), findsOneWidget);
  });

  testWidgets('precarga el correo del initialEmail (editable)', (tester) async {
    await tester.pumpWidget(host(initialEmail: 'op@example.com'));

    final email = tester.widget<AppTextField>(
      find.byKey(const Key('reset.email')),
    );
    expect(email.controller.text, 'op@example.com');
  });

  testWidgets('submit dispara ResetPasswordSubmitted con email+código+pass', (
    tester,
  ) async {
    await tester.pumpWidget(host(initialEmail: 'op@example.com'));

    await tester.enterText(find.byKey(const Key('reset.code')), '123456');
    await tester.enterText(
      find.byKey(const Key('reset.password')),
      'hunter2-secret',
    );
    await tester.tap(find.byKey(const Key('reset.submit')));
    await tester.pump();

    verify(
      () => bloc.add(
        const ResetPasswordSubmitted(
          email: 'op@example.com',
          code: '123456',
          newPassword: 'hunter2-secret',
        ),
      ),
    ).called(1);
  });

  testWidgets('reenviar dispara ForgotPasswordSubmitted con el correo', (
    tester,
  ) async {
    await tester.pumpWidget(host(initialEmail: 'op@example.com'));

    await tester.tap(find.byKey(const Key('reset.resend')));
    await tester.pump();

    verify(
      () => forgot.add(const ForgotPasswordSubmitted(email: 'op@example.com')),
    ).called(1);
  });

  testWidgets('reenviar con correo vacío avisa y NO dispara forgot', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.tap(find.byKey(const Key('reset.resend')));
    await tester.pump();

    expect(
      find.text('Escribe tu correo para reenviar el código'),
      findsOneWidget,
    );
    verifyNever(() => forgot.add(any()));
  });

  testWidgets('ForgotPasswordSent avisa "Te reenviamos el código"', (
    tester,
  ) async {
    whenListen(
      forgot,
      Stream<ForgotPasswordState>.fromIterable(const <ForgotPasswordState>[
        ForgotPasswordSent(),
      ]),
      initialState: const ForgotPasswordInitial(),
    );

    await tester.pumpWidget(host(initialEmail: 'op@example.com'));
    await tester.pump();

    expect(find.text('Te reenviamos el código'), findsOneWidget);
  });

  testWidgets('estado Submitting muestra el botón en loading', (tester) async {
    whenListen(
      bloc,
      Stream<ResetPasswordState>.fromIterable(const <ResetPasswordState>[
        ResetPasswordSubmitting(),
      ]),
      initialState: const ResetPasswordSubmitting(),
    );

    await tester.pumpWidget(host());

    final button = tester.widget<AppButton>(
      find.byKey(const Key('reset.submit')),
    );
    expect(button.loading, isTrue);
  });

  testWidgets('Failed(invalidCode) muestra mensaje de código incorrecto', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<ResetPasswordState>.fromIterable(const <ResetPasswordState>[
        ResetPasswordFailed(ResetPasswordFailureKind.invalidCode),
      ]),
      initialState: const ResetPasswordInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    final t = tester.widget<Text>(
      find.text('Código incorrecto. Revísalo o reenvía uno nuevo.'),
    );
    expect(t.style?.color, AppTokens.danger);
  });

  testWidgets('Failed(expiredCode) pide reenviar uno nuevo', (tester) async {
    whenListen(
      bloc,
      Stream<ResetPasswordState>.fromIterable(const <ResetPasswordState>[
        ResetPasswordFailed(ResetPasswordFailureKind.expiredCode),
      ]),
      initialState: const ResetPasswordInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('El código venció. Reenvía uno nuevo.'), findsOneWidget);
  });

  testWidgets('Failed(rateLimited) muestra el aviso de espera', (tester) async {
    whenListen(
      bloc,
      Stream<ResetPasswordState>.fromIterable(const <ResetPasswordState>[
        ResetPasswordFailed(ResetPasswordFailureKind.rateLimited),
      ]),
      initialState: const ResetPasswordInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(
      find.text('Demasiados intentos. Espera un momento e inténtalo de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('Failed(passwordTooShort) muestra mensaje de longitud', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<ResetPasswordState>.fromIterable(const <ResetPasswordState>[
        ResetPasswordFailed(ResetPasswordFailureKind.passwordTooShort),
      ]),
      initialState: const ResetPasswordInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(
      find.text('La contraseña debe tener al menos 12 caracteres'),
      findsOneWidget,
    );
  });

  testWidgets('estado Succeeded notifica al callback onSucceeded', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<ResetPasswordState>.fromIterable(const <ResetPasswordState>[
        ResetPasswordSucceeded(),
      ]),
      initialState: const ResetPasswordInitial(),
    );

    var notified = false;
    await tester.pumpWidget(host(onSucceeded: () => notified = true));
    await tester.pump();

    expect(notified, isTrue);
  });
}
