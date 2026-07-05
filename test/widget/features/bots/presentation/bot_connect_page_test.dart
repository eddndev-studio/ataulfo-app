import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_danger_zone.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
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

void main() {
  setUpAll(() {
    registerFallbackValue(const BotConnectStarted());
    registerFallbackValue(const BotConnectPairingRequested());
    registerFallbackValue(const BotConnectStopRequested());
    registerFallbackValue(const BotConnectWipeRequested());
  });

  late _MockBloc bloc;

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.state).thenReturn(const BotConnectLoading());
  });

  Widget host({BotChannel channel = BotChannel.waUnofficial}) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<BotConnectBloc>.value(
      value: bloc,
      child: Scaffold(body: BotConnectPage(channel: channel)),
    ),
  );

  testWidgets('Loading muestra spinner', (tester) async {
    when(() => bloc.state).thenReturn(const BotConnectLoading());

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Ready(idle): url + copiar + Iniciar emparejamiento', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(BotConnectReady(_link));

    await tester.pumpWidget(host());

    expect(find.text(_link.url), findsOneWidget);
    expect(find.text('Copiar enlace'), findsOneWidget);
    expect(find.text('Iniciar emparejamiento'), findsOneWidget);
  });

  testWidgets('Copiar enlace muestra confirmación', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    when(() => bloc.state).thenReturn(BotConnectReady(_link));

    await tester.pumpWidget(host());
    await tester.tap(find.text('Copiar enlace'));
    await tester.pump();

    expect(find.text('Enlace copiado'), findsOneWidget);
  });

  testWidgets('tap Iniciar emparejamiento → BotConnectPairingRequested', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(BotConnectReady(_link));

    await tester.pumpWidget(host());
    await tester.tap(find.text('Iniciar emparejamiento'));

    verify(() => bloc.add(const BotConnectPairingRequested())).called(1);
  });

  testWidgets('Ready(active): muestra el aviso de escaneo en vivo', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(BotConnectReady(_link, phase: PairingPhase.active));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bot_connect.active')), findsOneWidget);
  });

  testWidgets('Ready(active) sin QR aún: indica que se está generando', (
    tester,
  ) async {
    // En la fase active sin status.qrCode todavía no hay nada que escanear:
    // pedir "escanea el QR ahora" confunde. Debe verse el indicador de
    // generación en su lugar.
    when(
      () => bloc.state,
    ).thenReturn(BotConnectReady(_link, phase: PairingPhase.active));

    await tester.pumpWidget(host());

    expect(find.text('Generando el código QR…'), findsOneWidget);
    expect(find.byKey(const Key('bot_connect.qr')), findsNothing);
    expect(find.textContaining('escaneen el QR ahora'), findsNothing);
  });

  testWidgets('Failed muestra error y Reintentar dispara BotConnectStarted', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotConnectFailed(BotsServerFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bot_connect.error')), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    verify(() => bloc.add(const BotConnectStarted())).called(1);
  });

  testWidgets(
    'Ready(active): botón Desconectar dispara BotConnectStopRequested',
    (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(BotConnectReady(_link, phase: PairingPhase.active));

      await tester.pumpWidget(host());

      final stop = find.byKey(const Key('bot_connect.stop'));
      expect(stop, findsOneWidget);
      await tester.ensureVisible(stop);
      await tester.tap(stop);
      await tester.pump();

      verify(() => bloc.add(const BotConnectStopRequested())).called(1);
    },
  );

  group('wipe-credentials (S10, Tier B)', () {
    testWidgets(
      'WA_UNOFFICIAL: tap wipe → confirma → BotConnectWipeRequested',
      (tester) async {
        when(() => bloc.state).thenReturn(BotConnectReady(_link));

        await tester.pumpWidget(host());
        final wipe = find.byKey(const Key('bot_connect.wipe'));
        expect(wipe, findsOneWidget);
        await tester.ensureVisible(wipe);
        await tester.tap(wipe);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('bot_connect.wipe_confirm')),
          findsOneWidget,
        );
        verifyNever(() => bloc.add(const BotConnectWipeRequested()));

        await tester.tap(find.byKey(const Key('bot_connect.wipe_confirm')));
        await tester.pump();
        verify(() => bloc.add(const BotConnectWipeRequested())).called(1);
      },
    );

    testWidgets('confirmar el wipe muestra el SnackBar de confirmación', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(BotConnectReady(_link));

      await tester.pumpWidget(host());
      await tester.ensureVisible(find.byKey(const Key('bot_connect.wipe')));
      await tester.tap(find.byKey(const Key('bot_connect.wipe')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bot_connect.wipe_confirm')));
      await tester.pumpAndSettle();

      // El borrado es asíncrono y sin estado propio en el bloc: el SnackBar
      // es el único feedback de que la acción se registró.
      expect(find.textContaining('Credenciales borradas'), findsOneWidget);
    });

    testWidgets('WABA: la sección wipe está oculta', (tester) async {
      when(() => bloc.state).thenReturn(BotConnectReady(_link));

      await tester.pumpWidget(host(channel: BotChannel.waba));

      expect(find.byKey(const Key('bot_connect.wipe')), findsNothing);
      expect(find.byType(AppDangerZone), findsNothing);
    });

    testWidgets('la sección wipe es la Zona peligrosa canónica del kit', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(BotConnectReady(_link));

      await tester.pumpWidget(host());

      final zone = find.byType(AppDangerZone);
      expect(zone, findsOneWidget);
      expect(
        find.descendant(
          of: zone,
          matching: find.byKey(const Key('bot_connect.wipe')),
        ),
        findsOneWidget,
      );
      expect(find.text('Zona peligrosa'), findsOneWidget);
    });
  });

  group('estado real + QR (S11)', () {
    testWidgets('PAIRING con código muestra el QR escaneable', (tester) async {
      when(() => bloc.state).thenReturn(
        BotConnectReady(
          _link,
          phase: PairingPhase.active,
          status: const SessionStatus(
            state: SessionState.pairing,
            qrCode: 'QR-DATA',
          ),
        ),
      );

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('bot_connect.qr')), findsOneWidget);
    });

    testWidgets('CONNECTED muestra "Bot en línea" y no QR', (tester) async {
      when(() => bloc.state).thenReturn(
        BotConnectReady(
          _link,
          phase: PairingPhase.active,
          status: const SessionStatus(state: SessionState.connected),
        ),
      );

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('bot_connect.connected')), findsOneWidget);
      expect(find.text('Bot en línea'), findsOneWidget);
      expect(find.byKey(const Key('bot_connect.qr')), findsNothing);
    });

    testWidgets('qrExpired muestra aviso de expiración y re-ofrece Iniciar', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        BotConnectReady(
          _link,
          phase: PairingPhase.active,
          status: const SessionStatus(state: SessionState.disconnected),
          qrExpired: true,
        ),
      );

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('bot_connect.qr_expired')), findsOneWidget);
      expect(find.textContaining('expiró'), findsOneWidget);
      expect(find.text('Iniciar emparejamiento'), findsOneWidget);
    });
  });
}
