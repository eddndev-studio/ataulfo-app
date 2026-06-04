import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/features/auth/presentation/bloc/forgot_password_bloc.dart';
import 'package:ataulfo/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockForgotBloc extends MockBloc<ForgotPasswordEvent, ForgotPasswordState>
    implements ForgotPasswordBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const ForgotPasswordSubmitted(email: ''));
  });

  late _MockForgotBloc bloc;

  setUp(() {
    bloc = _MockForgotBloc();
    when(() => bloc.state).thenReturn(const ForgotPasswordInitial());
  });

  Widget host({VoidCallback? onHaveCode}) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<ForgotPasswordBloc>.value(
      value: bloc,
      child: ForgotPasswordPage(onHaveCode: onHaveCode),
    ),
  );

  testWidgets('renderiza campo email + AppButton de envío', (tester) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('forgot.email')), findsOneWidget);
    expect(find.byType(AppTextField), findsOneWidget);
    expect(find.byType(AppButton), findsOneWidget);
  });

  testWidgets('submit dispara ForgotPasswordSubmitted con el email', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.enterText(
      find.byKey(const Key('forgot.email')),
      'op@example.com',
    );
    await tester.tap(find.byType(AppButton));
    await tester.pump();

    verify(
      () => bloc.add(const ForgotPasswordSubmitted(email: 'op@example.com')),
    ).called(1);
  });

  testWidgets('estado Submitting muestra el botón en loading', (tester) async {
    whenListen(
      bloc,
      Stream<ForgotPasswordState>.fromIterable(const <ForgotPasswordState>[
        ForgotPasswordSubmitting(),
      ]),
      initialState: const ForgotPasswordSubmitting(),
    );

    await tester.pumpWidget(host());

    final button = tester.widget<AppButton>(find.byType(AppButton));
    expect(button.loading, isTrue);
  });

  testWidgets(
    'estado Sent muestra copy genérico y NO revela si la cuenta existe',
    (tester) async {
      whenListen(
        bloc,
        Stream<ForgotPasswordState>.fromIterable(const <ForgotPasswordState>[
          ForgotPasswordSent(),
        ]),
        initialState: const ForgotPasswordInitial(),
      );

      await tester.pumpWidget(host());
      await tester.pump();

      expect(
        find.text(
          'Si existe una cuenta con ese correo, te enviamos instrucciones '
          'para restablecer la contraseña.',
        ),
        findsOneWidget,
      );
      // El copy es condicional ("si existe"): jamás afirma que la cuenta
      // exista ni que el correo se haya enviado de verdad.
      expect(find.textContaining('te enviamos un correo a'), findsNothing);
      expect(find.textContaining('cuenta encontrada'), findsNothing);
    },
  );

  testWidgets('estado Failed(network) muestra mensaje de red', (tester) async {
    whenListen(
      bloc,
      Stream<ForgotPasswordState>.fromIterable(const <ForgotPasswordState>[
        ForgotPasswordFailed(ForgotPasswordFailureKind.network),
      ]),
      initialState: const ForgotPasswordInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    final t = tester.widget<Text>(find.text('Sin conexión, reintenta'));
    expect(t.style?.color, AppTokens.danger);
  });

  testWidgets('"Ya tengo un código" invoca onHaveCode', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(onHaveCode: () => tapped = true));

    await tester.tap(find.text('Ya tengo un código'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
