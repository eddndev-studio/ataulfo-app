import 'package:agentic/features/bots/domain/entities/bot.dart';
import 'package:agentic/features/bots/domain/failures/bots_failure.dart';
import 'package:agentic/features/bots/presentation/bloc/bot_detail_bloc.dart';
import 'package:agentic/features/bots/presentation/pages/bot_detail_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBotDetailBloc extends MockBloc<BotDetailEvent, BotDetailState>
    implements BotDetailBloc {}

const _bot = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: '52155...',
  version: 3,
  paused: false,
  aiDisabled: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const BotDetailLoadRequested());
  });

  late _MockBotDetailBloc bloc;

  setUp(() {
    bloc = _MockBotDetailBloc();
    when(() => bloc.state).thenReturn(const BotDetailLoading());
  });

  Widget host() => MaterialApp(
    home: BlocProvider<BotDetailBloc>.value(
      value: bloc,
      // BotDetailPage es content-only; el host envuelve en Scaffold para
      // dar Material upstream a los widgets internos (Chip, FilledButton).
      child: const Scaffold(body: BotDetailPage()),
    ),
  );

  testWidgets('Loading muestra spinner', (tester) async {
    when(() => bloc.state).thenReturn(const BotDetailLoading());

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Loaded muestra nombre, canal, version y avatar', (tester) async {
    when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

    await tester.pumpWidget(host());

    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    // La versión se muestra como `v{n}`; el operador la lee para sospechar
    // colisiones de CAS si reporta un bug post-edit.
    expect(find.text('v3'), findsOneWidget);
  });

  testWidgets('Loaded con paused: true muestra el badge "En pausa"', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const BotDetailLoaded(
        Bot(
          id: 'b2',
          orgId: 'o1',
          templateId: 't1',
          name: 'Cobranza',
          channel: BotChannel.waba,
          identifier: null,
          version: 1,
          paused: true,
          aiDisabled: false,
        ),
      ),
    );

    await tester.pumpWidget(host());

    expect(find.text('En pausa'), findsOneWidget);
  });

  testWidgets('Loaded sin paused no muestra el badge', (tester) async {
    when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

    await tester.pumpWidget(host());

    expect(find.text('En pausa'), findsNothing);
  });

  testWidgets('Failed con NotFound muestra copy específico + Reintentar', (
    tester,
  ) async {
    // El detalle es la primera pantalla que distingue NotFound del genérico:
    // un ID inválido o borrado merece un copy honesto, no "algo falló".
    when(
      () => bloc.state,
    ).thenReturn(const BotDetailFailed(BotsNotFoundFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bot_detail.error.not_found')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('Failed con otra failure muestra copy genérico + Reintentar', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotDetailFailed(BotsNetworkFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bot_detail.error.generic')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('tap Reintentar dispara BotDetailLoadRequested', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotDetailFailed(BotsServerFailure()));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(FilledButton, 'Reintentar'));
    await tester.pump();

    verify(() => bloc.add(const BotDetailLoadRequested())).called(1);
  });
}
