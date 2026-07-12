import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/bots/domain/entities/connect_link.dart';
import 'package:ataulfo/features/bots/domain/entities/session_status.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_connect_bloc.dart';
import 'package:ataulfo/features/bots/presentation/pages/bot_connect_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<BotConnectEvent, BotConnectState>
    implements BotConnectBloc {}

final _link = ConnectLink(
  url: 'https://api.ataulfo.app/connect?token=tok123',
  expiresAt: DateTime.utc(2026, 5, 29, 12, 30, 0),
);

const _pairing = SessionStatus(state: SessionState.pairing, qrCode: 'QR-DATA');

/// Estado Ready anclado al branch que muestra el QR (sesión PAIRING), donde
/// vive la sección pair-phone.
BotConnectReady _readyPairing({
  String? pairCode,
  bool pairRequesting = false,
  BotsFailure? pairFailure,
}) => BotConnectReady(
  _link,
  phase: PairingPhase.active,
  status: _pairing,
  pairCode: pairCode,
  pairRequesting: pairRequesting,
  pairFailure: pairFailure,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const BotConnectStarted());
    registerFallbackValue(const BotConnectPairCodeRequested(''));
  });

  late _MockBloc bloc;

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.state).thenReturn(const BotConnectLoading());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<BotConnectBloc>.value(
      value: bloc,
      child: const Scaffold(body: BotConnectPage()),
    ),
  );

  group('visibilidad', () {
    testWidgets('visible en el branch PAIRING con QR', (tester) async {
      when(() => bloc.state).thenReturn(_readyPairing());

      await tester.pumpWidget(host());

      expect(find.text('O vincula con un código'), findsOneWidget);
      expect(find.byKey(const Key('bot_connect.pair_phone')), findsOneWidget);
      expect(find.byKey(const Key('bot_connect.pair_submit')), findsOneWidget);
    });

    testWidgets('oculta en Ready(idle) sin sesión', (tester) async {
      when(() => bloc.state).thenReturn(BotConnectReady(_link));

      await tester.pumpWidget(host());

      expect(find.text('O vincula con un código'), findsNothing);
      expect(find.byKey(const Key('bot_connect.pair_phone')), findsNothing);
    });

    testWidgets('oculta en fase active sin QR todavía', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(BotConnectReady(_link, phase: PairingPhase.active));

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('bot_connect.pair_phone')), findsNothing);
    });
  });

  group('validación local', () {
    testWidgets('número corto: error en sitio y NO toca el bloc', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(_readyPairing());

      await tester.pumpWidget(host());
      await tester.ensureVisible(
        find.byKey(const Key('bot_connect.pair_phone')),
      );
      await tester.enterText(
        find.byKey(const Key('bot_connect.pair_phone')),
        '123456',
      );
      await tester.ensureVisible(
        find.byKey(const Key('bot_connect.pair_submit')),
      );
      await tester.tap(find.byKey(const Key('bot_connect.pair_submit')));
      await tester.pump();

      expect(find.text('Escribe el número completo con lada.'), findsOneWidget);
      verifyNever(
        () => bloc.add(any(that: isA<BotConnectPairCodeRequested>())),
      );
    });

    testWidgets('número válido: dispara el evento con el saneado', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(_readyPairing());

      await tester.pumpWidget(host());
      await tester.ensureVisible(
        find.byKey(const Key('bot_connect.pair_phone')),
      );
      await tester.enterText(
        find.byKey(const Key('bot_connect.pair_phone')),
        '5215512345678',
      );
      await tester.ensureVisible(
        find.byKey(const Key('bot_connect.pair_submit')),
      );
      await tester.tap(find.byKey(const Key('bot_connect.pair_submit')));
      await tester.pump();

      verify(
        () => bloc.add(const BotConnectPairCodeRequested('5215512345678')),
      ).called(1);
    });
  });

  group('código recibido', () {
    testWidgets('se pinta TAL CUAL con su instructivo', (tester) async {
      when(() => bloc.state).thenReturn(_readyPairing(pairCode: 'WZYX-K9PT'));

      await tester.pumpWidget(host());

      final codeText = tester.widget<SelectableText>(
        find.byKey(const Key('bot_connect.pair_code')),
      );
      expect(codeText.data, 'WZYX-K9PT');
      expect(
        find.text(
          'En WhatsApp: Dispositivos vinculados › Vincular con el número de '
          'teléfono. Válido ~2 minutos.',
        ),
        findsOneWidget,
      );
      expect(find.text('Copiar código'), findsOneWidget);
    });

    testWidgets('Copiar código muestra confirmación', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      when(() => bloc.state).thenReturn(_readyPairing(pairCode: 'WZYX-K9PT'));

      await tester.pumpWidget(host());
      await tester.ensureVisible(find.text('Copiar código'));
      await tester.tap(find.text('Copiar código'));
      await tester.pump();

      expect(find.text('Código copiado'), findsOneWidget);
    });
  });

  group('pedida en vuelo', () {
    testWidgets('el botón entra en loading (label fuera, spinner dentro)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(_readyPairing(pairRequesting: true));

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('bot_connect.pair_submit')), findsOneWidget);
      expect(find.text('Generar código'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('bot_connect.pair_submit')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    });
  });

  group('copy de fallos (frases fijas)', () {
    Future<void> pumpFailure(WidgetTester tester, BotsFailure f) async {
      when(() => bloc.state).thenReturn(_readyPairing(pairFailure: f));
      await tester.pumpWidget(host());
    }

    testWidgets('PairingNotStarted', (tester) async {
      await pumpFailure(tester, const BotsPairingNotStartedFailure());
      expect(find.text('Primero inicia el emparejamiento.'), findsOneWidget);
    });

    testWidgets('PhoneRejected', (tester) async {
      await pumpFailure(tester, const BotsPhoneRejectedFailure());
      expect(
        find.text(
          'Número no aceptado. Usa formato internacional sin “+” '
          '(p. ej. 5215512345678).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Network y Timeout', (tester) async {
      await pumpFailure(tester, const BotsNetworkFailure());
      expect(
        find.text('Sin conexión. Revisa tu red e intenta de nuevo.'),
        findsOneWidget,
      );
      await pumpFailure(tester, const BotsTimeoutFailure());
      expect(
        find.text('Sin conexión. Revisa tu red e intenta de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('resto → genérico', (tester) async {
      await pumpFailure(tester, const BotsServerFailure());
      expect(
        find.text('No pudimos generar el código. Inténtalo de nuevo.'),
        findsOneWidget,
      );
    });
  });
}
