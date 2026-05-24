import 'package:agentic/features/bots/domain/entities/bot.dart';
import 'package:agentic/features/bots/domain/failures/bots_failure.dart';
import 'package:agentic/features/bots/presentation/bloc/bots_bloc.dart';
import 'package:agentic/features/bots/presentation/pages/bots_list_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBotsBloc extends MockBloc<BotsEvent, BotsState>
    implements BotsBloc {}

const _b1 = Bot(
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
const _b2 = Bot(
  id: 'b2',
  orgId: 'o1',
  templateId: 't1',
  name: 'Cobranza',
  channel: BotChannel.waba,
  identifier: null,
  version: 1,
  paused: true,
  aiDisabled: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const BotsLoadRequested());
  });

  late _MockBotsBloc bloc;

  setUp(() {
    bloc = _MockBotsBloc();
    when(() => bloc.state).thenReturn(const BotsInitial());
  });

  Widget host() => MaterialApp(
    home: BlocProvider<BotsBloc>.value(
      value: bloc,
      child: const BotsListPage(),
    ),
  );

  testWidgets('Loading muestra spinner', (tester) async {
    when(() => bloc.state).thenReturn(const BotsLoading());

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Loaded con N bots renderiza un tile por cada uno', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_b1, _b2], isRefreshing: false));

    await tester.pumpWidget(host());

    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('Cobranza'), findsOneWidget);
  });

  testWidgets('Loaded vacío muestra empty state (sin tiles)', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[], isRefreshing: false));

    await tester.pumpWidget(host());

    // El copy preciso es decisión de UI; alcanza con verificar que NO hay
    // tiles renderizados con nombres de bots y que el árbol contiene un
    // mensaje (cualquier Text) que el operador puede leer.
    expect(find.text('Soporte'), findsNothing);
    expect(find.text('Cobranza'), findsNothing);
    expect(find.byKey(const Key('bots.empty')), findsOneWidget);
  });

  testWidgets('Failed muestra mensaje genérico y botón Reintentar', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const BotsFailed(BotsNetworkFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bots.error')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('tap Reintentar dispara BotsLoadRequested', (tester) async {
    when(() => bloc.state).thenReturn(const BotsFailed(BotsServerFailure()));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(FilledButton, 'Reintentar'));
    await tester.pump();

    verify(() => bloc.add(const BotsLoadRequested())).called(1);
  });

  testWidgets('isRefreshing: true muestra la lista visible (no la oculta)', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_b1], isRefreshing: true));

    await tester.pumpWidget(host());

    // El contrato del shape `BotsLoaded(isRefreshing)` es justamente este:
    // la lista permanece visible mientras el spinner del RefreshIndicator
    // hace overlay (timing del overlay no es testeable de forma estable).
    expect(find.text('Soporte'), findsOneWidget);
  });
}
