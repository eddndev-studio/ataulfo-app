import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/features/auth/presentation/bloc/reset_password_bloc.dart';
import 'package:ataulfo/features/auth/presentation/pages/reset_password_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockResetBloc extends MockBloc<ResetPasswordEvent, ResetPasswordState>
    implements ResetPasswordBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const ResetPasswordSubmitted(pastedLinkOrToken: '', newPassword: ''),
    );
  });

  late _MockResetBloc bloc;

  setUp(() {
    bloc = _MockResetBloc();
    when(() => bloc.state).thenReturn(const ResetPasswordInitial());
  });

  Widget host({VoidCallback? onSucceeded}) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<ResetPasswordBloc>.value(
      value: bloc,
      child: ResetPasswordPage(onSucceeded: onSucceeded),
    ),
  );

  testWidgets('renderiza campo de pegado + nueva contraseña + AppButton', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('reset.token')), findsOneWidget);
    expect(find.byKey(const Key('reset.password')), findsOneWidget);
    expect(find.byType(AppTextField), findsNWidgets(2));
    expect(find.byType(AppButton), findsOneWidget);
  });

  testWidgets('la nueva contraseña lleva obscureText + obscureToggle', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    final pw = tester.widget<AppTextField>(
      find.byKey(const Key('reset.password')),
    );
    expect(pw.obscureText, isTrue);
    expect(pw.obscureToggle, isTrue);
  });

  testWidgets('submit dispara ResetPasswordSubmitted con pegado + contraseña', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.enterText(
      find.byKey(const Key('reset.token')),
      'https://ataulfo.app/reset?token=tok123',
    );
    await tester.enterText(
      find.byKey(const Key('reset.password')),
      'hunter2-secret',
    );
    await tester.tap(find.byType(AppButton));
    await tester.pump();

    verify(
      () => bloc.add(
        const ResetPasswordSubmitted(
          pastedLinkOrToken: 'https://ataulfo.app/reset?token=tok123',
          newPassword: 'hunter2-secret',
        ),
      ),
    ).called(1);
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

    final button = tester.widget<AppButton>(find.byType(AppButton));
    expect(button.loading, isTrue);
  });

  testWidgets('Failed(invalidLink) muestra mensaje de enlace inválido', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<ResetPasswordState>.fromIterable(const <ResetPasswordState>[
        ResetPasswordFailed(ResetPasswordFailureKind.invalidLink),
      ]),
      initialState: const ResetPasswordInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    final t = tester.widget<Text>(
      find.text('El enlace no es válido. Solicita uno nuevo.'),
    );
    expect(t.style?.color, AppTokens.danger);
  });

  testWidgets('Failed(expiredLink) pide solicitar uno nuevo', (tester) async {
    whenListen(
      bloc,
      Stream<ResetPasswordState>.fromIterable(const <ResetPasswordState>[
        ResetPasswordFailed(ResetPasswordFailureKind.expiredLink),
      ]),
      initialState: const ResetPasswordInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(
      find.text('El enlace caducó. Solicita uno nuevo.'),
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

  testWidgets('Failed(invalidInput) pide pegar el enlace o código', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<ResetPasswordState>.fromIterable(const <ResetPasswordState>[
        ResetPasswordFailed(ResetPasswordFailureKind.invalidInput),
      ]),
      initialState: const ResetPasswordInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(
      find.text('Pega el enlace o el código que recibiste por correo'),
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
