import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_variables_bloc.dart';
import 'package:ataulfo/features/bots/presentation/pages/bot_variables_page.dart';
import 'package:ataulfo/features/templates/domain/entities/variable_def.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<BotVariablesEvent, BotVariablesState>
    implements BotVariablesBloc {}

const _defs = <VariableDef>[
  VariableDef(
    id: 'v1',
    name: 'tono',
    type: VarType.text,
    defaultValue: 'neutral',
    description: 'Tono de las respuestas',
  ),
  VariableDef(
    id: 'v2',
    name: 'firma',
    type: VarType.text,
    defaultValue: 'El equipo',
    description: 'Firma al cierre',
  ),
];

void main() {
  setUpAll(() {
    registerFallbackValue(const BotVariablesSaveRequested(<String, String>{}));
    registerFallbackValue(const BotVariablesLoadRequested());
  });

  late _MockBloc bloc;
  setUp(() => bloc = _MockBloc());

  Widget host({required BotVariablesState state}) {
    when(() => bloc.state).thenReturn(state);
    whenListen(
      bloc,
      const Stream<BotVariablesState>.empty(),
      initialState: state,
    );
    return MaterialApp(
      theme: AppDesignTheme.dark(),
      home: BlocProvider<BotVariablesBloc>.value(
        value: bloc,
        child: const Scaffold(body: BotVariablesPage()),
      ),
    );
  }

  testWidgets('Loaded: banner WRITE-ONLY + un campo por def + Guardar', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(state: const BotVariablesLoaded(defs: _defs, botVersion: 5)),
    );

    // Banner prominente de la limitación.
    expect(find.textContaining('reemplazan'), findsOneWidget);
    // Un campo por VariableDef.
    expect(find.byKey(const Key('bot_variables.field.tono')), findsOneWidget);
    expect(find.byKey(const Key('bot_variables.field.firma')), findsOneWidget);
    // Label = name; helper = description; placeholder = defaultValue.
    expect(find.text('tono'), findsOneWidget);
    expect(find.text('Tono de las respuestas'), findsOneWidget);
    expect(find.byKey(const Key('bot_variables.submit')), findsOneWidget);
  });

  testWidgets('submit con un override → SaveRequested({tono}) omitiendo vacíos', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(state: const BotVariablesLoaded(defs: _defs, botVersion: 5)),
    );

    await tester.enterText(
      find.byKey(const Key('bot_variables.field.tono')),
      'formal',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('bot_variables.submit')));

    verify(
      () => bloc.add(
        const BotVariablesSaveRequested(<String, String>{'tono': 'formal'}),
      ),
    ).called(1);
  });

  testWidgets('submit sin tocar nada → SaveRequested({}) (vaciar = {})', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(state: const BotVariablesLoaded(defs: _defs, botVersion: 5)),
    );

    await tester.tap(find.byKey(const Key('bot_variables.submit')));

    verify(
      () => bloc.add(const BotVariablesSaveRequested(<String, String>{})),
    ).called(1);
  });

  testWidgets('Empty muestra copy de plantilla sin variables', (tester) async {
    await tester.pumpWidget(host(state: const BotVariablesEmpty()));
    expect(find.textContaining('no declara variables'), findsOneWidget);
  });

  testWidgets('Failed(notFound) muestra copy + Reintentar', (tester) async {
    await tester.pumpWidget(
      host(state: const BotVariablesFailed(BotVariablesLoadError.notFound)),
    );
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    verify(() => bloc.add(const BotVariablesLoadRequested())).called(1);
  });

  testWidgets('SaveFailed(conflict) muestra copy de versión', (tester) async {
    await tester.pumpWidget(
      host(
        state: const BotVariablesSaveFailed(
          defs: _defs,
          botVersion: 5,
          failure: BotsConflictFailure(),
        ),
      ),
    );
    expect(find.textContaining('desactualizad'), findsOneWidget);
  });

  testWidgets('Saved → hace pop de la página', (tester) async {
    final ctrl = StreamController<BotVariablesState>.broadcast();
    addTearDown(ctrl.close);
    const loaded = BotVariablesLoaded(defs: _defs, botVersion: 5);
    when(() => bloc.state).thenReturn(loaded);
    whenListen(bloc, ctrl.stream, initialState: loaded);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<BotVariablesBloc>.value(
          value: bloc,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider<BotVariablesBloc>.value(
                      value: bloc,
                      child: const Scaffold(body: BotVariablesPage()),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bot_variables.submit')), findsOneWidget);

    ctrl.add(const BotVariablesSaved());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bot_variables.submit')), findsNothing);
  });
}
