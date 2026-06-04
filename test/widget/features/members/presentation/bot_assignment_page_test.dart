import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/members/presentation/bloc/assign_bots_cubit.dart';
import 'package:ataulfo/features/members/presentation/pages/bot_assignment_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAssignBotsCubit extends MockCubit<AssignBotsState>
    implements AssignBotsCubit {}

Bot _bot(String id, String name) => Bot(
  id: id,
  orgId: 'o1',
  templateId: 't1',
  name: name,
  channel: BotChannel.waUnofficial,
  identifier: null,
  version: 1,
  paused: false,
  aiDisabled: false,
);

final _bots = <Bot>[_bot('b1', 'Uno'), _bot('b2', 'Dos')];

void main() {
  late _MockAssignBotsCubit cubit;

  setUp(() {
    cubit = _MockAssignBotsCubit();
    when(() => cubit.state).thenReturn(const AssignBotsLoading());
    when(() => cubit.toggle(any())).thenReturn(null);
    when(cubit.load).thenAnswer((_) async {});
    when(cubit.save).thenAnswer((_) async {});
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<AssignBotsCubit>.value(
      value: cubit,
      child: const Scaffold(body: BotAssignmentPage()),
    ),
  );

  testWidgets('Loading muestra spinner', (tester) async {
    when(() => cubit.state).thenReturn(const AssignBotsLoading());

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Ready lista un check por bot, con el asignado marcado', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      AssignBotsReady(bots: _bots, selected: const <String>{'b2'}),
    );

    await tester.pumpWidget(host());

    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(find.text('Uno'), findsOneWidget);
    expect(find.text('Dos'), findsOneWidget);
    final checks = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(checks[0].value, isFalse); // b1 no asignado
    expect(checks[1].value, isTrue); // b2 asignado
  });

  testWidgets('tocar un bot dispara toggle(id)', (tester) async {
    when(() => cubit.state).thenReturn(
      AssignBotsReady(bots: _bots, selected: const <String>{}),
    );

    await tester.pumpWidget(host());
    await tester.tap(find.text('Uno'));
    await tester.pump();

    verify(() => cubit.toggle('b1')).called(1);
  });

  testWidgets('Guardar dispara save()', (tester) async {
    when(() => cubit.state).thenReturn(
      AssignBotsReady(bots: _bots, selected: const <String>{'b1'}),
    );

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('bot_assignment.save')));
    await tester.pump();

    verify(cubit.save).called(1);
  });

  testWidgets('Ready sin bots muestra el copy de org sin bots', (tester) async {
    when(() => cubit.state).thenReturn(
      const AssignBotsReady(bots: <Bot>[], selected: <String>{}),
    );

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bot_assignment.empty')), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets('Failed(load) muestra error y Reintentar dispara load()', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const AssignBotsFailed(AssignBotsPhase.load));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bot_assignment.error')), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();

    verify(cubit.load).called(1);
  });

  testWidgets('Saved cierra la pantalla y avisa', (tester) async {
    whenListen(
      cubit,
      Stream<AssignBotsState>.fromIterable(const <AssignBotsState>[
        AssignBotsSaving(),
        AssignBotsSaved(),
      ]),
      initialState: AssignBotsReady(bots: _bots, selected: const <String>{}),
    );

    final popped = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Navigator(
          onPopPage: (route, result) {
            popped.add(true);
            return route.didPop(result);
          },
          pages: <Page<dynamic>>[
            MaterialPage<void>(
              child: BlocProvider<AssignBotsCubit>.value(
                value: cubit,
                child: const Scaffold(body: BotAssignmentPage()),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Bots actualizados'), findsOneWidget);
    expect(popped, isNotEmpty);
  });
}
