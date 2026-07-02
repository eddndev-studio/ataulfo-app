import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_code_field.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/features/auth/presentation/bloc/verify_email_bloc.dart';
import 'package:ataulfo/features/auth/presentation/pages/verify_email_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockVerifyBloc extends MockBloc<VerifyEmailEvent, VerifyEmailState>
    implements VerifyEmailBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const VerifyEmailSubmitted(email: '', code: ''));
  });

  late _MockVerifyBloc bloc;

  setUp(() {
    bloc = _MockVerifyBloc();
    when(() => bloc.state).thenReturn(const VerifyEmailInitial());
  });

  Widget host({
    String initialEmail = '',
    void Function({required bool alreadyVerified})? onSucceeded,
    VoidCallback? onResend,
    VoidCallback? onSkip,
  }) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<VerifyEmailBloc>.value(
      value: bloc,
      child: VerifyEmailPage(
        initialEmail: initialEmail,
        onSucceeded: onSucceeded,
        onResend: onResend,
        onSkip: onSkip,
      ),
    ),
  );

  testWidgets('renderiza email + código + botón verificar', (tester) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('verify.email')), findsOneWidget);
    expect(find.byKey(const Key('verify.code')), findsOneWidget);
    expect(find.byKey(const Key('verify.submit')), findsOneWidget);
    expect(find.byType(AppCodeField), findsOneWidget);
  });

  testWidgets('precarga el correo del initialEmail', (tester) async {
    await tester.pumpWidget(host(initialEmail: 'op@example.com'));

    final email = tester.widget<AppTextField>(
      find.byKey(const Key('verify.email')),
    );
    expect(email.controller.text, 'op@example.com');
  });

  testWidgets('submit dispara VerifyEmailSubmitted con email+código', (
    tester,
  ) async {
    await tester.pumpWidget(host(initialEmail: 'op@example.com'));

    await tester.enterText(find.byKey(const Key('verify.code')), '123456');
    await tester.tap(find.byKey(const Key('verify.submit')));
    await tester.pump();

    verify(
      () => bloc.add(
        const VerifyEmailSubmitted(email: 'op@example.com', code: '123456'),
      ),
    ).called(1);
  });

  testWidgets('sin sesión no pinta reenviar ni omitir', (tester) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('verify.resend')), findsNothing);
    expect(find.byKey(const Key('verify.skip')), findsNothing);
  });

  testWidgets('con sesión pinta reenviar y omitir', (tester) async {
    await tester.pumpWidget(host(onResend: () {}, onSkip: () {}));

    expect(find.byKey(const Key('verify.resend')), findsOneWidget);
    expect(find.byKey(const Key('verify.skip')), findsOneWidget);
  });

  testWidgets('"Omitir por ahora" invoca onSkip', (tester) async {
    var skipped = false;
    await tester.pumpWidget(host(onSkip: () => skipped = true));

    await tester.tap(find.byKey(const Key('verify.skip')));
    await tester.pump();

    expect(skipped, isTrue);
  });

  testWidgets('estado Submitting muestra el botón en loading', (tester) async {
    whenListen(
      bloc,
      Stream<VerifyEmailState>.fromIterable(const <VerifyEmailState>[
        VerifyEmailSubmitting(),
      ]),
      initialState: const VerifyEmailSubmitting(),
    );

    await tester.pumpWidget(host());

    final button = tester.widget<AppButton>(
      find.byKey(const Key('verify.submit')),
    );
    expect(button.loading, isTrue);
  });

  testWidgets('Failed(invalidCode) muestra mensaje de código incorrecto', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<VerifyEmailState>.fromIterable(const <VerifyEmailState>[
        VerifyEmailFailed(VerifyEmailFailureKind.invalidCode),
      ]),
      initialState: const VerifyEmailInitial(),
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
      Stream<VerifyEmailState>.fromIterable(const <VerifyEmailState>[
        VerifyEmailFailed(VerifyEmailFailureKind.expiredCode),
      ]),
      initialState: const VerifyEmailInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('El código venció. Reenvía uno nuevo.'), findsOneWidget);
  });

  testWidgets('Failed(rateLimited) muestra el aviso de espera', (tester) async {
    whenListen(
      bloc,
      Stream<VerifyEmailState>.fromIterable(const <VerifyEmailState>[
        VerifyEmailFailed(VerifyEmailFailureKind.rateLimited),
      ]),
      initialState: const VerifyEmailInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(
      find.text('Demasiados intentos. Espera un momento e inténtalo de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('Succeeded(fresca) muestra SnackBar de confirmación', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<VerifyEmailState>.fromIterable(const <VerifyEmailState>[
        VerifyEmailSucceeded(alreadyVerified: false),
      ]),
      initialState: const VerifyEmailInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('Verificación completada'), findsOneWidget);
  });

  testWidgets('Succeeded(ya verificada) NO muestra SnackBar', (tester) async {
    whenListen(
      bloc,
      Stream<VerifyEmailState>.fromIterable(const <VerifyEmailState>[
        VerifyEmailSucceeded(alreadyVerified: true),
      ]),
      initialState: const VerifyEmailInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('Verificación completada'), findsNothing);
  });

  testWidgets(
    'Succeeded notifica al callback onSucceeded con alreadyVerified',
    (tester) async {
      whenListen(
        bloc,
        Stream<VerifyEmailState>.fromIterable(const <VerifyEmailState>[
          VerifyEmailSucceeded(alreadyVerified: true),
        ]),
        initialState: const VerifyEmailInitial(),
      );

      bool? notifiedAlready;
      await tester.pumpWidget(
        host(
          onSucceeded: ({required bool alreadyVerified}) =>
              notifiedAlready = alreadyVerified,
        ),
      );
      await tester.pump();

      expect(notifiedAlready, isTrue);
    },
  );
}
