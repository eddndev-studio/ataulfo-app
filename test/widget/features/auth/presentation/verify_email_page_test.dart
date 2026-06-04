import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
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
    registerFallbackValue(const VerifyEmailSubmitted(''));
  });

  late _MockVerifyBloc bloc;

  setUp(() {
    bloc = _MockVerifyBloc();
    when(() => bloc.state).thenReturn(const VerifyEmailInitial());
  });

  Widget host({void Function({required bool alreadyVerified})? onSucceeded}) =>
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<VerifyEmailBloc>.value(
          value: bloc,
          child: VerifyEmailPage(onSucceeded: onSucceeded),
        ),
      );

  testWidgets('renderiza campo de pegado + AppButton', (tester) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('verify.token')), findsOneWidget);
    expect(find.byType(AppTextField), findsOneWidget);
    expect(find.byType(AppButton), findsOneWidget);
  });

  testWidgets('submit dispara VerifyEmailSubmitted con el pegado', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.enterText(
      find.byKey(const Key('verify.token')),
      'https://ataulfo.app/verify?token=tok123',
    );
    await tester.tap(find.byType(AppButton));
    await tester.pump();

    verify(
      () => bloc.add(
        const VerifyEmailSubmitted('https://ataulfo.app/verify?token=tok123'),
      ),
    ).called(1);
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

    final button = tester.widget<AppButton>(find.byType(AppButton));
    expect(button.loading, isTrue);
  });

  testWidgets('Failed(invalidLink) muestra mensaje de enlace inválido', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<VerifyEmailState>.fromIterable(const <VerifyEmailState>[
        VerifyEmailFailed(VerifyEmailFailureKind.invalidLink),
      ]),
      initialState: const VerifyEmailInitial(),
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
      Stream<VerifyEmailState>.fromIterable(const <VerifyEmailState>[
        VerifyEmailFailed(VerifyEmailFailureKind.expiredLink),
      ]),
      initialState: const VerifyEmailInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('El enlace caducó. Solicita uno nuevo.'), findsOneWidget);
  });

  testWidgets('Failed(invalidInput) pide pegar el enlace o código', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<VerifyEmailState>.fromIterable(const <VerifyEmailState>[
        VerifyEmailFailed(VerifyEmailFailureKind.invalidInput),
      ]),
      initialState: const VerifyEmailInitial(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(
      find.text('Pega el enlace o el código que recibiste por correo'),
      findsOneWidget,
    );
  });

  testWidgets('Succeeded(alreadyVerified:false) muestra "Correo verificado"', (
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

    expect(find.text('Correo verificado'), findsOneWidget);
    expect(find.text('Tu correo ya estaba verificado'), findsNothing);
  });

  testWidgets(
    'Succeeded(alreadyVerified:true) muestra "Tu correo ya estaba verificado"',
    (tester) async {
      whenListen(
        bloc,
        Stream<VerifyEmailState>.fromIterable(const <VerifyEmailState>[
          VerifyEmailSucceeded(alreadyVerified: true),
        ]),
        initialState: const VerifyEmailInitial(),
      );

      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.text('Tu correo ya estaba verificado'), findsOneWidget);
      expect(find.text('Correo verificado'), findsNothing);
    },
  );

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
