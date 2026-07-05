import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_empty_state.dart';
import 'package:ataulfo/core/design/widgets/app_error_state.dart';
import 'package:ataulfo/core/design/widgets/app_loading_indicator.dart';
import 'package:ataulfo/features/flows/domain/entities/flow.dart' as fdom;
import 'package:ataulfo/features/flows/domain/failures/flows_failure.dart';
import 'package:ataulfo/features/flows/presentation/bloc/flow_detail_bloc.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/repositories/labels_repository.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_bloc.dart';
import 'package:ataulfo/features/triggers/domain/entities/trigger.dart';
import 'package:ataulfo/features/triggers/domain/failures/triggers_failure.dart';
import 'package:ataulfo/features/triggers/domain/repositories/triggers_repository.dart';
import 'package:ataulfo/features/triggers/presentation/bloc/triggers_bloc.dart';
import 'package:ataulfo/features/triggers/presentation/pages/flow_triggers_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDetailBloc extends MockBloc<FlowDetailEvent, FlowDetailState>
    implements FlowDetailBloc {}

class _MockTriggersBloc extends MockBloc<TriggersEvent, TriggersState>
    implements TriggersBloc {}

class _MockLabelsBloc extends MockBloc<LabelsEvent, LabelsState>
    implements LabelsBloc {}

class _MockTriggersRepo extends Mock implements TriggersRepository {}

class _MockLabelsRepo extends Mock implements LabelsRepository {}

Label _lbl({String id = 'vip', String name = 'VIP'}) =>
    Label(id: id, name: name, color: '#FF8800', description: '');

fdom.Flow _flow({String id = 'f1', String name = 'Bienvenida'}) => fdom.Flow(
  id: id,
  templateId: 'tpl1',
  name: name,
  isActive: true,
  version: 1,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: const <String>[],
);

Trigger _text({
  String id = 't1',
  String keyword = 'menu',
  String flowId = 'f1',
}) => Trigger(
  id: id,
  templateId: 'tpl1',
  flowId: flowId,
  triggerType: TriggerType.text,
  matchType: MatchType.contains,
  keyword: keyword,
  labelId: '',
  labelAction: null,
  scope: TriggerScope.both,
  isActive: true,
  createdAt: DateTime.utc(2026, 5, 1),
  updatedAt: DateTime.utc(2026, 5, 1),
);

Trigger _label({
  String id = 'lt1',
  String labelId = 'vip',
  String flowId = 'f1',
  LabelAction action = LabelAction.add,
}) => Trigger(
  id: id,
  templateId: 'tpl1',
  flowId: flowId,
  triggerType: TriggerType.label,
  matchType: null,
  keyword: '',
  labelId: labelId,
  labelAction: action,
  scope: TriggerScope.both,
  isActive: true,
  createdAt: DateTime.utc(2026, 5, 1),
  updatedAt: DateTime.utc(2026, 5, 1),
);

/// `FlowTriggersBody` es la unidad bajo prueba: consumer-only, espera
/// el `TriggersBloc` en el árbol. El wrapper que construye los blocs se
/// cubre en el grupo de cableado; la página que resuelve el flujo desde
/// el `FlowDetailBloc`, en el grupo de la página.
Widget _harness({
  required _MockTriggersBloc triggers,
  required fdom.Flow flow,
  _MockLabelsBloc? labels,
  LabelsState? labelsState,
}) {
  final lbls = labels ?? _MockLabelsBloc();
  when(
    () => lbls.state,
  ).thenReturn(labelsState ?? LabelsLoaded(<Label>[_lbl()]));
  return MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<TriggersBloc>.value(value: triggers),
        BlocProvider<LabelsBloc>.value(value: lbls),
      ],
      child: Scaffold(body: FlowTriggersBody(flow: flow)),
    ),
  );
}

void main() {
  late _MockTriggersBloc triggers;

  setUp(() {
    triggers = _MockTriggersBloc();
  });

  testWidgets('Loading muestra el indicador canónico', (tester) async {
    when(() => triggers.state).thenReturn(const TriggersLoading());

    await tester.pumpWidget(_harness(triggers: triggers, flow: _flow()));

    expect(find.byKey(const Key('flow_triggers.loading')), findsOneWidget);
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
  });

  testWidgets('Loaded con lista vacía muestra el empty canónico con CTA que '
      'abre el sheet', (tester) async {
    when(() => triggers.state).thenReturn(const TriggersLoaded(<Trigger>[]));

    await tester.pumpWidget(_harness(triggers: triggers, flow: _flow()));

    final empty = find.byKey(const Key('flow_triggers.empty'));
    expect(empty, findsOneWidget);
    expect(tester.widget(empty), isA<AppEmptyState>());
    // El alta vive en la CTA del vacío; el botón de texto no se duplica.
    expect(find.byKey(const Key('flow_triggers.add_button')), findsNothing);

    await tester.tap(find.text('Crear disparador'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo disparador'), findsOneWidget);
    expect(find.byKey(const Key('trigger_edit.flow_fixed')), findsOneWidget);
  });

  testWidgets('Loaded con filas: UNA card las apila con divider (dialecto '
      'denso)', (tester) async {
    when(() => triggers.state).thenReturn(
      TriggersLoaded(<Trigger>[
        _text(id: 'a', keyword: 'hola'),
        _text(id: 'b', keyword: 'menu'),
      ]),
    );

    await tester.pumpWidget(_harness(triggers: triggers, flow: _flow()));

    expect(find.byType(AppCard), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppCard), matching: find.byType(Divider)),
      findsOneWidget,
    );
    expect(find.byKey(const Key('flow_triggers.row.a')), findsOneWidget);
    expect(find.byKey(const Key('flow_triggers.row.b')), findsOneWidget);
  });

  testWidgets(
    'Loaded filtra los triggers: solo los que matchean flow.id se renderizan',
    (tester) async {
      // Mezcla deliberada: el endpoint /templates/:id/triggers devuelve
      // todos los triggers de la template; la página debe ocultar los que
      // no pertenezcan al flow del scope.
      when(() => triggers.state).thenReturn(
        TriggersLoaded(<Trigger>[
          _text(id: 'mine-a', keyword: 'hola', flowId: 'f1'),
          _text(id: 'other', keyword: 'pagos', flowId: 'f2'),
          _text(id: 'mine-b', keyword: 'menu', flowId: 'f1'),
        ]),
      );

      await tester.pumpWidget(
        _harness(
          triggers: triggers,
          flow: _flow(id: 'f1'),
        ),
      );

      expect(find.byKey(const Key('flow_triggers.row.mine-a')), findsOneWidget);
      expect(find.byKey(const Key('flow_triggers.row.mine-b')), findsOneWidget);
      expect(find.byKey(const Key('flow_triggers.row.other')), findsNothing);
      // Ningún row debe mostrar la pill "→ flow", redundante en scope.
      expect(find.textContaining('→'), findsNothing);
    },
  );

  testWidgets('Failed muestra el error canónico + retry que dispatcha load', (
    tester,
  ) async {
    when(
      () => triggers.state,
    ).thenReturn(const TriggersFailed(TriggersNetworkFailure()));

    await tester.pumpWidget(_harness(triggers: triggers, flow: _flow()));

    final failed = find.byKey(const Key('flow_triggers.failed'));
    expect(failed, findsOneWidget);
    expect(tester.widget(failed), isA<AppErrorState>());
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    verify(() => triggers.add(const TriggersLoadRequested())).called(1);
  });

  testWidgets(
    'Failed NotFound del template padre cae a copy flow-scope sin retry',
    (tester) async {
      when(
        () => triggers.state,
      ).thenReturn(const TriggersFailed(TriggersNotFoundFailure()));

      await tester.pumpWidget(_harness(triggers: triggers, flow: _flow()));

      expect(find.byKey(const Key('flow_triggers.failed')), findsOneWidget);
      // No queremos botón "Reintentar" cuando el template ya no existe.
      expect(find.text('Reintentar'), findsNothing);
    },
  );

  testWidgets('Mutating preserva la lista visible (snapshot)', (tester) async {
    when(
      () => triggers.state,
    ).thenReturn(TriggersMutating(<Trigger>[_text(id: 'a', flowId: 'f1')]));

    await tester.pumpWidget(
      _harness(
        triggers: triggers,
        flow: _flow(id: 'f1'),
      ),
    );

    expect(find.byKey(const Key('flow_triggers.row.a')), findsOneWidget);
  });

  testWidgets('tap en add_button abre el TriggerEditSheet con scopedFlow', (
    tester,
  ) async {
    when(
      () => triggers.state,
    ).thenReturn(TriggersLoaded(<Trigger>[_text(id: 'a', flowId: 'f1')]));

    await tester.pumpWidget(
      _harness(
        triggers: triggers,
        flow: _flow(id: 'f1', name: 'Bienvenida'),
      ),
    );
    await tester.tap(find.byKey(const Key('flow_triggers.add_button')));
    await tester.pumpAndSettle();

    // El sheet aparece — verificamos la presencia del título de create
    // y que la línea fija renderiza el nombre del flow (no el dropdown).
    expect(find.text('Nuevo disparador'), findsOneWidget);
    expect(find.byKey(const Key('trigger_edit.flow_fixed')), findsOneWidget);
    expect(find.byKey(const Key('trigger_edit.flow_dropdown')), findsNothing);
  });

  testWidgets('tap en una row abre el sheet en modo edit con scopedFlow', (
    tester,
  ) async {
    when(() => triggers.state).thenReturn(
      TriggersLoaded(<Trigger>[
        _text(id: 'mine', keyword: 'hola', flowId: 'f1'),
      ]),
    );

    await tester.pumpWidget(
      _harness(
        triggers: triggers,
        flow: _flow(id: 'f1', name: 'Bienvenida'),
      ),
    );
    await tester.tap(find.byKey(const Key('flow_triggers.row.mine.tap')));
    await tester.pumpAndSettle();

    expect(find.text('Editar disparador'), findsOneWidget);
    expect(find.byKey(const Key('trigger_edit.flow_fixed')), findsOneWidget);
  });

  group('Row de trigger LABEL resuelve labelId → nombre', () {
    testWidgets('catálogo cargado y presente: muestra el nombre, no el id', (
      tester,
    ) async {
      when(
        () => triggers.state,
      ).thenReturn(TriggersLoaded(<Trigger>[_label(id: 'lt', labelId: 'vip')]));

      await tester.pumpWidget(
        _harness(
          triggers: triggers,
          flow: _flow(id: 'f1'),
          labelsState: LabelsLoaded(<Label>[_lbl(id: 'vip', name: 'VIP')]),
        ),
      );

      expect(find.text('VIP'), findsOneWidget);
      // El id crudo NUNCA debe quedar visible.
      expect(find.text('vip'), findsNothing);
    });

    testWidgets('catálogo cargado y ausente: muestra "Etiqueta eliminada"', (
      tester,
    ) async {
      when(() => triggers.state).thenReturn(
        TriggersLoaded(<Trigger>[_label(id: 'lt', labelId: 'ghost')]),
      );

      await tester.pumpWidget(
        _harness(
          triggers: triggers,
          flow: _flow(id: 'f1'),
          labelsState: LabelsLoaded(<Label>[_lbl(id: 'vip', name: 'VIP')]),
        ),
      );

      expect(find.text('Etiqueta eliminada'), findsOneWidget);
      expect(find.text('ghost'), findsNothing);
    });

    testWidgets('catálogo cargando: NO muestra "eliminada" (evita flash)', (
      tester,
    ) async {
      when(
        () => triggers.state,
      ).thenReturn(TriggersLoaded(<Trigger>[_label(id: 'lt', labelId: 'vip')]));

      await tester.pumpWidget(
        _harness(
          triggers: triggers,
          flow: _flow(id: 'f1'),
          labelsState: const LabelsLoading(),
        ),
      );

      // Mientras el catálogo carga no podemos afirmar que la etiqueta no
      // existe; mostramos el id como placeholder, nunca "Etiqueta eliminada".
      expect(find.text('Etiqueta eliminada'), findsNothing);
      expect(find.text('vip'), findsOneWidget);
    });
  });

  group('FlowTriggersPage · resuelve el flujo desde el FlowDetailBloc', () {
    late _MockDetailBloc detail;
    late _MockTriggersRepo triggersRepo;
    late _MockLabelsRepo labelsRepo;

    setUp(() {
      detail = _MockDetailBloc();
      triggersRepo = _MockTriggersRepo();
      labelsRepo = _MockLabelsRepo();
      when(
        () => triggersRepo.listTriggers(any()),
      ).thenAnswer((_) => Completer<List<Trigger>>().future);
      when(() => labelsRepo.listLabels()).thenAnswer((_) async => <Label>[]);
    });

    Widget pageHost() => MaterialApp(
      theme: AppDesignTheme.dark(),
      home: MultiRepositoryProvider(
        providers: <RepositoryProvider<dynamic>>[
          RepositoryProvider<TriggersRepository>.value(value: triggersRepo),
          RepositoryProvider<LabelsRepository>.value(value: labelsRepo),
        ],
        child: BlocProvider<FlowDetailBloc>.value(
          value: detail,
          child: const Scaffold(body: FlowTriggersPage()),
        ),
      ),
    );

    testWidgets('cabecera cargando → indicador canónico', (tester) async {
      when(() => detail.state).thenReturn(const FlowDetailLoading());

      await tester.pumpWidget(pageHost());

      expect(find.byType(AppLoadingIndicator), findsOneWidget);
    });

    testWidgets('cabecera fallida → error canónico con retry', (tester) async {
      when(
        () => detail.state,
      ).thenReturn(const FlowDetailFailed(FlowsServerFailure()));

      await tester.pumpWidget(pageHost());

      expect(find.byType(AppErrorState), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      verify(() => detail.add(const FlowDetailLoadRequested())).called(1);
    });

    testWidgets('cabecera cargada → monta el scope con su TriggersBloc '
        'propio (carga en vuelo visible)', (tester) async {
      when(() => detail.state).thenReturn(
        FlowDetailLoaded(_flow(), const <fdom.Flow>[], siblingsFailed: false),
      );

      await tester.pumpWidget(pageHost());
      await tester.pump();

      expect(find.byKey(const Key('flow_triggers.loading')), findsOneWidget);
      verify(() => triggersRepo.listTriggers('tpl1')).called(1);
    });
  });

  group('cableado del catálogo al sheet', () {
    testWidgets(
      'el selector del sheet ve los labels del LabelsRepository del scope',
      (tester) async {
        // Pump del wrapper REAL (construye TriggersBloc + LabelsBloc desde
        // los repos del scope) para cubrir la gotcha: el sheet monta en una
        // ruta nueva del Navigator y solo ve los labels si `_openSheet`
        // re-proveyó el LabelsBloc al subtree del modal.
        final triggersRepo = _MockTriggersRepo();
        final labelsRepo = _MockLabelsRepo();
        when(
          () => triggersRepo.listTriggers(any()),
        ).thenAnswer((_) async => <Trigger>[]);
        when(
          () => labelsRepo.listLabels(),
        ).thenAnswer((_) async => <Label>[_lbl(id: 'vip', name: 'VIP')]);

        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppDesignTheme.dark(),
            home: MultiRepositoryProvider(
              providers: <RepositoryProvider<dynamic>>[
                RepositoryProvider<TriggersRepository>.value(
                  value: triggersRepo,
                ),
                RepositoryProvider<LabelsRepository>.value(value: labelsRepo),
              ],
              child: Scaffold(body: FlowTriggersScope(flow: _flow())),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Crear disparador'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Etiqueta'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('trigger_edit.label_picker.option.vip')),
          findsOneWidget,
        );
        expect(find.text('VIP'), findsOneWidget);
      },
    );
  });
}
