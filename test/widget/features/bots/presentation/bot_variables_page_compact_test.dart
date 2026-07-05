import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
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

VariableDef _def(String id, String name, [String desc = '']) =>
    VariableDef(id: id, name: name, defaultValue: '', description: desc);

/// 7 defs (> 5) disparan el modo compacto: buscador + tarjetas colapsables.
final _manyDefs = <VariableDef>[
  _def('v1', 'tono', 'Tono de las respuestas'),
  _def('v2', 'firma', 'Firma al cierre'),
  _def('v3', 'saludo'),
  _def('v4', 'horario'),
  _def('v5', 'promo'),
  _def('v6', 'canal'),
  _def('v7', 'cierre'),
];

/// 5 defs (== umbral) conservan el layout plano de siempre.
final _fewDefs = _manyDefs.take(5).toList(growable: false);

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

  /// Viewport alto: el modo compacto pinta 7 tarjetas + banner + submit y los
  /// taps de los tests necesitan los targets dentro del área visible.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Finder card(String name) => find.byKey(Key('bot_variables.card.$name'));
  Finder field(String name) => find.byKey(Key('bot_variables.field.$name'));
  Finder preview(String name) => find.byKey(Key('bot_variables.preview.$name'));
  final search = find.byKey(const Key('bot_variables.search'));
  final submit = find.byKey(const Key('bot_variables.submit'));

  /// Colapsa/expande una tarjeta YA expandida tocando su chevron (el centro
  /// de una tarjeta expandida cae sobre el TextField y ganaría el tap).
  Future<void> tapChevron(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(of: card(name), matching: find.byIcon(Icons.expand_less)),
    );
    await tester.pump();
  }

  testWidgets(
    'con 5 defs o menos NO hay buscador ni tarjetas: Column plano de siempre',
    (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        host(state: BotVariablesLoaded(defs: _fewDefs, botVersion: 5)),
      );

      expect(search, findsNothing);
      for (final d in _fewDefs) {
        expect(field(d.name), findsOneWidget);
        expect(card(d.name), findsNothing);
      }
      expect(submit, findsOneWidget);
    },
  );

  testWidgets(
    'con más de 5 defs: buscador + tarjetas colapsadas, salvo las que ya '
    'tienen valor guardado (auto-expandidas y precargadas)',
    (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        host(
          state: BotVariablesLoaded(
            defs: _manyDefs,
            botVersion: 5,
            currentValues: const <String, String>{'firma': 'El equipo'},
          ),
        ),
      );

      expect(search, findsOneWidget);
      // Todas las variables tienen tarjeta; solo 'firma' (con override)
      // arranca expandida mostrando su campo precargado.
      for (final d in _manyDefs) {
        expect(card(d.name), findsOneWidget);
      }
      expect(field('tono'), findsNothing);
      expect(field('firma'), findsOneWidget);
      final firma = tester.widget<AppTextField>(field('firma'));
      expect(firma.controller.text, 'El equipo');
      expect(submit, findsOneWidget);
    },
  );

  testWidgets('tocar una tarjeta la expande; tocar su chevron la colapsa', (
    tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(
      host(state: BotVariablesLoaded(defs: _manyDefs, botVersion: 5)),
    );

    expect(field('tono'), findsNothing);
    await tester.tap(card('tono'));
    await tester.pump();
    expect(field('tono'), findsOneWidget);

    await tapChevron(tester, 'tono');
    expect(field('tono'), findsNothing);
  });

  testWidgets(
    'tarjeta colapsada con valor muestra preview de UNA línea (saltos → espacio)',
    (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        host(
          state: BotVariablesLoaded(
            defs: _manyDefs,
            botVersion: 5,
            currentValues: const <String, String>{
              'firma': 'El equipo\nAtaulfo',
            },
          ),
        ),
      );

      // Expandida (por tener valor) no pinta preview: el campo ya muestra
      // el texto completo.
      expect(preview('firma'), findsNothing);

      await tapChevron(tester, 'firma');
      expect(field('firma'), findsNothing);
      final previewText = tester.widget<Text>(preview('firma'));
      expect(previewText.data, 'El equipo Ataulfo');
      expect(previewText.maxLines, 1);
    },
  );

  testWidgets(
    'buscar filtra por nombre (case-insensitive, contains) y AUTO-EXPANDE '
    'los matches sin tap extra',
    (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        host(state: BotVariablesLoaded(defs: _manyDefs, botVersion: 5)),
      );

      await tester.enterText(search, 'TON');
      await tester.pump();

      expect(card('tono'), findsOneWidget);
      expect(field('tono'), findsOneWidget, reason: 'match auto-expandido');
      expect(card('firma'), findsNothing);
      expect(card('promo'), findsNothing);
      expect(submit, findsOneWidget);
    },
  );

  testWidgets('búsqueda sin matches muestra aviso y el submit sigue ahí', (
    tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(
      host(state: BotVariablesLoaded(defs: _manyDefs, botVersion: 5)),
    );

    await tester.enterText(search, 'zzz');
    await tester.pump();

    for (final d in _manyDefs) {
      expect(card(d.name), findsNothing);
    }
    expect(find.byKey(const Key('bot_variables.no_results')), findsOneWidget);
    expect(submit, findsOneWidget);
  });

  testWidgets(
    'INVARIANTE: el valor escrito viaja al submit aunque su tarjeta quede '
    'FILTRADA fuera de vista por la búsqueda',
    (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        host(
          state: BotVariablesLoaded(
            defs: _manyDefs,
            botVersion: 5,
            currentValues: const <String, String>{'firma': 'El equipo'},
          ),
        ),
      );

      await tester.tap(card('tono'));
      await tester.pump();
      await tester.enterText(
        field('tono'),
        'Cálido y directo.\nSin tecnicismos.',
      );
      await tester.pump();

      // Filtrar 'firma' saca a 'tono' de la vista — presentacional, no
      // destructivo: su controller conserva el texto.
      await tester.enterText(search, 'firma');
      await tester.pump();
      expect(field('tono'), findsNothing);

      await tester.tap(submit);
      verify(
        () => bloc.add(
          const BotVariablesSaveRequested(<String, String>{
            'tono': 'Cálido y directo.\nSin tecnicismos.',
            'firma': 'El equipo',
          }),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'INVARIANTE: el valor escrito viaja al submit aunque su tarjeta esté '
    'COLAPSADA al momento de guardar',
    (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        host(
          state: BotVariablesLoaded(
            defs: _manyDefs,
            botVersion: 5,
            currentValues: const <String, String>{'firma': 'El equipo'},
          ),
        ),
      );

      await tester.tap(card('tono'));
      await tester.pump();
      await tester.enterText(field('tono'), 'formal');
      await tester.pump();
      await tapChevron(tester, 'tono');
      expect(field('tono'), findsNothing);

      await tester.tap(submit);
      verify(
        () => bloc.add(
          const BotVariablesSaveRequested(<String, String>{
            'tono': 'formal',
            'firma': 'El equipo',
          }),
        ),
      ).called(1);
    },
  );
}
