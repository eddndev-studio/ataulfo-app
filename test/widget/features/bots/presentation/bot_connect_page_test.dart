import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/features/bots/domain/entities/connect_link.dart';
import 'package:agentic/features/bots/domain/failures/bots_failure.dart';
import 'package:agentic/features/bots/presentation/bloc/bot_connect_bloc.dart';
import 'package:agentic/features/bots/presentation/pages/bot_connect_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<BotConnectEvent, BotConnectState>
    implements BotConnectBloc {}

final _link = ConnectLink(
  url: 'https://api.w-gateway.cc/connect?token=tok123',
  expiresAt: DateTime.utc(2026, 5, 29, 12, 30, 0),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const BotConnectStarted());
    registerFallbackValue(const BotConnectPairingRequested());
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
}
