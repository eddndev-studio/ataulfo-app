import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/features/flows/domain/entities/flow.dart' as fdom;
import 'package:agentic/features/flows/presentation/bloc/flows_bloc.dart';
import 'package:agentic/features/triggers/domain/entities/trigger.dart';
import 'package:agentic/features/triggers/domain/failures/triggers_failure.dart';
import 'package:agentic/features/triggers/presentation/bloc/triggers_bloc.dart';
import 'package:agentic/features/triggers/presentation/widgets/trigger_edit_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTriggersBloc extends MockBloc<TriggersEvent, TriggersState>
    implements TriggersBloc {}

class _MockFlowsBloc extends MockBloc<FlowsEvent, FlowsState>
    implements FlowsBloc {}

fdom.Flow _flow({
  String id = 'f1',
  String name = 'Bienvenida',
  bool isActive = true,
}) => fdom.Flow(
  id: id,
  templateId: 'tpl1',
  name: name,
  isActive: isActive,
  version: 1,
);

Trigger _textTrigger({
  String id = 't1',
  String keyword = 'menu',
  String flowId = 'f1',
  bool isActive = true,
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
  isActive: isActive,
  createdAt: DateTime.utc(2026, 5, 1),
  updatedAt: DateTime.utc(2026, 5, 1),
);

Trigger _labelTrigger({String id = 't2', String labelId = 'vip'}) => Trigger(
  id: id,
  templateId: 'tpl1',
  flowId: 'f1',
  triggerType: TriggerType.label,
  matchType: null,
  keyword: '',
  labelId: labelId,
  labelAction: LabelAction.add,
  scope: TriggerScope.both,
  isActive: true,
  createdAt: DateTime.utc(2026, 5, 1),
  updatedAt: DateTime.utc(2026, 5, 1),
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const TriggersAddRequested(
        flowId: 'f1',
        triggerType: TriggerType.text,
        matchType: MatchType.exact,
        keyword: '',
        labelId: '',
        labelAction: null,
        scope: TriggerScope.both,
        isActive: true,
      ),
    );
  });

  late _MockTriggersBloc triggers;
  late _MockFlowsBloc flows;

  setUp(() {
    triggers = _MockTriggersBloc();
    flows = _MockFlowsBloc();
    when(() => triggers.state).thenReturn(const TriggersLoaded(<Trigger>[]));
    when(() => flows.state).thenReturn(
      FlowsLoaded(<fdom.Flow>[_flow(), _flow(id: 'f2', name: 'Pagos')]),
    );
  });

  // El sheet completo con todos los controles supera el viewport
  // default de flutter_test (800x600). pumpHost agranda y restaura.
  Future<void> pumpHost(WidgetTester tester, {Trigger? editing}) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<TriggersBloc>.value(value: triggers),
            BlocProvider<FlowsBloc>.value(value: flows),
          ],
          child: Scaffold(
            body: SafeArea(child: TriggerEditSheet(editing: editing)),
          ),
        ),
      ),
    );
  }

  group('TriggerEditSheet (Add mode)', () {
    testWidgets('renderiza título "Nuevo disparador" + controles base', (
      tester,
    ) async {
      await pumpHost(tester);

      expect(find.text('Nuevo disparador'), findsOneWidget);
      expect(find.byKey(const Key('trigger_edit.type_picker')), findsOneWidget);
      expect(find.byKey(const Key('trigger_edit.match_picker')), findsOneWidget);
      expect(find.byKey(const Key('trigger_edit.scope_picker')), findsOneWidget);
      expect(find.byKey(const Key('trigger_edit.keyword')), findsOneWidget);
      expect(find.byKey(const Key('trigger_edit.flow_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('trigger_edit.active_switch')), findsOneWidget);
      expect(find.byKey(const Key('trigger_edit.submit')), findsOneWidget);
    });

    testWidgets('submit con keyword vacío es no-op', (tester) async {
      await pumpHost(tester);

      await tester.tap(find.byKey(const Key('trigger_edit.submit')));
      await tester.pump();

      verifyNever(() => triggers.add(any()));
    });

    testWidgets(
      'submit TEXT con keyword + flow → AddRequested con shape TEXT',
      (tester) async {
        await pumpHost(tester);

        await tester.enterText(
          find.byKey(const Key('trigger_edit.keyword')),
          'hola',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('trigger_edit.flow_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bienvenida').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('trigger_edit.submit')));
        await tester.pump();

        verify(
          () => triggers.add(
            const TriggersAddRequested(
              flowId: 'f1',
              triggerType: TriggerType.text,
              matchType: MatchType.exact,
              keyword: 'hola',
              labelId: '',
              labelAction: null,
              scope: TriggerScope.both,
              isActive: true,
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'submit con flow no elegido es no-op aunque keyword esté lleno',
      (tester) async {
        await pumpHost(tester);

        await tester.enterText(
          find.byKey(const Key('trigger_edit.keyword')),
          'hola',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('trigger_edit.submit')));
        await tester.pump();

        verifyNever(() => triggers.add(any()));
      },
    );
  });

  group('TriggerEditSheet (Add mode · LABEL)', () {
    testWidgets(
      'cambiar a LABEL oculta keyword/match/scope y muestra labelId + labelAction',
      (tester) async {
        await pumpHost(tester);

        // TEXT por default — keyword visible.
        expect(find.byKey(const Key('trigger_edit.keyword')), findsOneWidget);

        await tester.tap(find.text('Etiqueta'));
        await tester.pump();

        expect(find.byKey(const Key('trigger_edit.keyword')), findsNothing);
        expect(find.byKey(const Key('trigger_edit.match_picker')), findsNothing);
        expect(find.byKey(const Key('trigger_edit.scope_picker')), findsNothing);
        expect(find.byKey(const Key('trigger_edit.label_id')), findsOneWidget);
        expect(
          find.byKey(const Key('trigger_edit.label_action_picker')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'submit LABEL dispatcha AddRequested con shape LABEL (sin keyword/match)',
      (tester) async {
        await pumpHost(tester);

        await tester.tap(find.text('Etiqueta'));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('trigger_edit.label_id')),
          'vip',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('trigger_edit.flow_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bienvenida').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('trigger_edit.submit')));
        await tester.pump();

        verify(
          () => triggers.add(
            const TriggersAddRequested(
              flowId: 'f1',
              triggerType: TriggerType.label,
              matchType: null,
              keyword: '',
              labelId: 'vip',
              labelAction: LabelAction.add,
              scope: TriggerScope.both,
              isActive: true,
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('submit LABEL con labelId vacío es no-op', (tester) async {
      await pumpHost(tester);

      await tester.tap(find.text('Etiqueta'));
      await tester.pump();
      // Sin enterText en labelId.
      await tester.tap(find.byKey(const Key('trigger_edit.flow_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bienvenida').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('trigger_edit.submit')));
      await tester.pump();

      verifyNever(() => triggers.add(any()));
    });
  });
}
