import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
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
    defaultValue: 'neutral',
    description: 'Tono de las respuestas',
  ),
  VariableDef(
    id: 'v2',
    name: 'firma',
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

  testWidgets(
    'Loaded PRECARGA el valor guardado de cada variable (no solo placeholder)',
    (tester) async {
      await tester.pumpWidget(
        host(
          state: const BotVariablesLoaded(
            defs: _defs,
            botVersion: 5,
            currentValues: <String, String>{'tono': 'formal'},
          ),
        ),
      );

      // 'tono' tiene override guardado → el campo lo PRECARGA como texto.
      final tono = tester.widget<AppTextField>(
        find.byKey(const Key('bot_variables.field.tono')),
      );
      expect(tono.controller.text, 'formal');

      // 'firma' sin override → arranca vacío (su default va de placeholder).
      final firma = tester.widget<AppTextField>(
        find.byKey(const Key('bot_variables.field.firma')),
      );
      expect(firma.controller.text, '');
    },
  );

  testWidgets(
    'submit SIN tocar nada PRESERVA los overrides precargados (no los borra)',
    (tester) async {
      // Regresión del footgun: antes el form arrancaba vacío y un
      // reabrir-y-guardar enviaba {} (borraba TODOS los overrides). Con la
      // precarga, guardar sin cambios reenvía el set guardado.
      await tester.pumpWidget(
        host(
          state: const BotVariablesLoaded(
            defs: _defs,
            botVersion: 5,
            currentValues: <String, String>{'tono': 'formal'},
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('bot_variables.submit')));

      verify(
        () => bloc.add(
          const BotVariablesSaveRequested(<String, String>{'tono': 'formal'}),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'submit con un override → SaveRequested({tono}) omitiendo vacíos',
    (tester) async {
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
    },
  );

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
    await tester.pump(); // entrega del stream → listener (pop + showSnackBar)
    await tester.pump(); // frame en que el messenger monta el SnackBar
    // Confirmación visible ANTES de que el pop desmonte la página: sin el
    // SnackBar el guardado sería silencioso y el operador no sabría si
    // funcionó. (findsWidgets: durante la transición ambos Scaffolds están
    // registrados en el messenger y el aviso se pinta en los dos.)
    expect(find.text('Variables guardadas'), findsWidgets);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bot_variables.submit')), findsNothing);
    // El SnackBar sobrevive al pop (messenger del MaterialApp raíz).
    expect(find.text('Variables guardadas'), findsOneWidget);
  });
}
