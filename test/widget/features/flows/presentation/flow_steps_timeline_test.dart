import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/flows/domain/entities/step.dart' as fdom;
import 'package:ataulfo/features/flows/presentation/bloc/flow_steps_bloc.dart';
import 'package:ataulfo/features/flows/presentation/bloc/media_names_cubit.dart';
import 'package:ataulfo/features/flows/presentation/widgets/flow_steps_section.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/repositories/labels_repository.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStepsBloc extends MockBloc<FlowStepsEvent, FlowStepsState>
    implements FlowStepsBloc {}

class _MockMediaNamesCubit extends MockCubit<MediaNamesState>
    implements MediaNamesCubit {}

class _MockLabelsBloc extends MockBloc<LabelsEvent, LabelsState>
    implements LabelsBloc {}

class _MockLabelsRepo extends Mock implements LabelsRepository {}

fdom.Step _text(String id, int order, {int delayMs = 1000}) => fdom.Step(
  id: id,
  flowId: 'f1',
  type: fdom.StepType.text,
  order: order,
  content: 'msg $id',
  mediaRef: '',
  metadataJson: '{}',
  delayMs: delayMs,
  jitterPct: 0,
  aiOnly: false,
);

fdom.Step _ct(String id, int order, String matchId, String elseId) => fdom.Step(
  id: id,
  flowId: 'f1',
  type: fdom.StepType.conditionalTime,
  order: order,
  content: '',
  mediaRef: '',
  metadataJson:
      '{"tz":"UTC","windows":[{"days":[1],"from":"09:00","to":"18:00"}],'
      '"on_match_step_id":"$matchId","on_else_step_id":"$elseId"}',
  delayMs: 1000,
  jitterPct: 0,
  aiOnly: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const FlowStepsAddRequested(
        content: '',
        delayMs: 0,
        jitterPct: 0,
        aiOnly: false,
      ),
    );
  });

  late _MockStepsBloc bloc;
  late _MockMediaNamesCubit mediaNames;
  late _MockLabelsBloc labels;
  late _MockLabelsRepo labelsRepo;

  setUp(() {
    bloc = _MockStepsBloc();
    mediaNames = _MockMediaNamesCubit();
    labels = _MockLabelsBloc();
    labelsRepo = _MockLabelsRepo();
    when(() => mediaNames.state).thenReturn(const MediaNamesState());
    when(() => labels.state).thenReturn(const LabelsLoading());
    when(() => labelsRepo.listLabels()).thenAnswer((_) async => <Label>[]);
  });

  Future<void> pumpSection(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: RepositoryProvider<LabelsRepository>.value(
            value: labelsRepo,
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<FlowStepsBloc>.value(value: bloc),
                BlocProvider<MediaNamesCubit>.value(value: mediaNames),
                BlocProvider<LabelsBloc>.value(value: labels),
              ],
              child: const FlowStepsSection(),
            ),
          ),
        ),
      ),
    );
  }

  group('el timeline habla el idioma del kit', () {
    testWidgets('mensajes como burbuja, lógica como fila técnica y delay '
        'como caption quieta (sin pill)', (tester) async {
      when(() => bloc.state).thenReturn(
        FlowStepsLoaded(<fdom.Step>[
          _text('a', 0, delayMs: 1500),
          _ct('ct', 1, 'b', 'c'),
          _text('b', 2),
          _text('c', 3),
        ]),
      );
      await pumpSection(tester);

      // La burbuja del mensaje y su caption de tipo + retraso.
      expect(find.text('msg a'), findsOneWidget);
      expect(find.text('· 1.5s'), findsOneWidget);
      // El retraso ya no es pill: ninguna cápsula lleva el delay.
      expect(find.widgetWithText(AppPill, '1.5s'), findsNothing);
      // La fila técnica del condicional: resumen estructurado presente.
      expect(find.textContaining('Zona UTC'), findsOneWidget);
      // Saltos de rama etiquetados, derivados del condicional.
      expect(find.text('si cumple'), findsOneWidget);
      expect(find.text('si no'), findsOneWidget);
    });
  });

  group('inserción posicional desde el "+" entre filas', () {
    testWidgets('el "+" abre el creador y el alta viaja con order = la '
        'posición elegida', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(FlowStepsLoaded(<fdom.Step>[_text('a', 0), _text('b', 1)]));
      await pumpSection(tester);

      // Zona discreta entre la fila 0 y la 1: inserta en la posición 1.
      await tester.tap(find.byKey(const Key('app_step_timeline.insert.1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('step_edit.type.text')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('step_edit.content')),
          matching: find.byType(TextField),
        ),
        'intercalado',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pumpAndSettle();

      final captured = verify(
        () => bloc.add(captureAny()),
      ).captured.whereType<FlowStepsAddRequested>();
      expect(captured, hasLength(1));
      expect(captured.single.order, 1);
      expect(captured.single.content, 'intercalado');
    });

    testWidgets('el inserter del final appendea (order = longitud)', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(FlowStepsLoaded(<fdom.Step>[_text('a', 0), _text('b', 1)]));
      await pumpSection(tester);

      await tester.tap(find.byKey(const Key('flow_detail.steps.add_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('step_edit.type.text')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('step_edit.content')),
          matching: find.byType(TextField),
        ),
        'al final',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pumpAndSettle();

      final captured = verify(
        () => bloc.add(captureAny()),
      ).captured.whereType<FlowStepsAddRequested>();
      expect(captured, hasLength(1));
      expect(captured.single.order, 2);
    });
  });

  group('anuncio del paso recién creado', () {
    testWidgets('un id nuevo en el listado refrescado enciende el glow de '
        'su fila', (tester) async {
      final states = StreamController<FlowStepsState>.broadcast();
      addTearDown(states.close);
      final before = <fdom.Step>[_text('a', 0), _text('b', 1)];
      final after = <fdom.Step>[
        _text('a', 0),
        _text('nuevo', 1),
        _text('b', 2),
      ];
      whenListen(bloc, states.stream, initialState: FlowStepsLoaded(before));
      await pumpSection(tester);
      expect(find.byKey(const Key('app_timeline_row.highlight')), findsNothing);

      states.add(FlowStepsLoaded(after));
      await tester.pump();
      await tester.pump();

      final highlight = find.byKey(const Key('app_timeline_row.highlight'));
      expect(highlight, findsOneWidget);
      // El glow abraza a la fila del paso NUEVO.
      expect(
        find.descendant(of: highlight, matching: find.text('msg nuevo')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('un reorder (mismos ids) no anuncia nada', (tester) async {
      final states = StreamController<FlowStepsState>.broadcast();
      addTearDown(states.close);
      final before = <fdom.Step>[_text('a', 0), _text('b', 1)];
      final after = <fdom.Step>[_text('b', 0), _text('a', 1)];
      whenListen(bloc, states.stream, initialState: FlowStepsLoaded(before));
      await pumpSection(tester);

      states.add(FlowStepsLoaded(after));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('app_timeline_row.highlight')), findsNothing);
      await tester.pumpAndSettle();
    });
  });
}
