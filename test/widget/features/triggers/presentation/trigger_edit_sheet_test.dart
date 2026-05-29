import 'dart:async';

import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/core/design/widgets/app_switch.dart';
import 'package:agentic/features/flows/domain/entities/flow.dart' as fdom;
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
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: const <String>[],
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

  setUp(() {
    triggers = _MockTriggersBloc();
    when(() => triggers.state).thenReturn(const TriggersLoaded(<Trigger>[]));
  });

  // El sheet completo con todos los controles supera el viewport
  // default de flutter_test (800x600). pumpHost agranda y restaura.
  Future<void> pumpHost(
    WidgetTester tester, {
    Trigger? editing,
    fdom.Flow? scopedFlow,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<TriggersBloc>.value(
          value: triggers,
          child: Scaffold(
            body: SafeArea(
              child: TriggerEditSheet(
                editing: editing,
                scopedFlow: scopedFlow ?? _flow(),
              ),
            ),
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
      expect(
        find.byKey(const Key('trigger_edit.match_picker')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('trigger_edit.scope_picker')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('trigger_edit.keyword')), findsOneWidget);
      expect(find.byKey(const Key('trigger_edit.flow_fixed')), findsOneWidget);
      expect(find.byKey(const Key('trigger_edit.flow_dropdown')), findsNothing);
      expect(
        find.byKey(const Key('trigger_edit.active_switch')),
        findsOneWidget,
      );
      expect(find.byType(AppSwitch), findsOneWidget);
      expect(find.byKey(const Key('trigger_edit.submit')), findsOneWidget);
    });

    testWidgets('submit con keyword vacío es no-op', (tester) async {
      await pumpHost(tester);

      await tester.tap(find.byKey(const Key('trigger_edit.submit')));
      await tester.pump();

      verifyNever(() => triggers.add(any()));
    });

    testWidgets(
      'submit TEXT con keyword → AddRequested con flowId del scopedFlow',
      (tester) async {
        await pumpHost(tester);

        await tester.enterText(
          find.byKey(const Key('trigger_edit.keyword')),
          'hola',
        );
        await tester.pump();
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
        expect(
          find.byKey(const Key('trigger_edit.match_picker')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('trigger_edit.scope_picker')),
          findsNothing,
        );
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
      await tester.tap(find.byKey(const Key('trigger_edit.submit')));
      await tester.pump();

      verifyNever(() => triggers.add(any()));
    });
  });

  group('TriggerEditSheet (Edit mode)', () {
    testWidgets(
      'TEXT trigger: hidrata keyword/match/scope + línea read-only de flow',
      (tester) async {
        await pumpHost(tester, editing: _textTrigger());

        expect(find.text('Editar disparador'), findsOneWidget);
        expect(
          find.widgetWithText(TextField, 'menu'),
          findsOneWidget,
          reason: 'keyword hidratado',
        );
        // El flow es el del scope: línea fija con el nombre del flow
        // del editor, sin dropdown.
        expect(
          find.byKey(const Key('trigger_edit.flow_dropdown')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('trigger_edit.flow_fixed')),
          findsOneWidget,
        );
        expect(find.textContaining('Bienvenida'), findsOneWidget);
      },
    );

    testWidgets(
      'LABEL trigger: hidrata labelId + labelAction; sin keyword/match',
      (tester) async {
        await pumpHost(tester, editing: _labelTrigger());

        expect(
          find.widgetWithText(TextField, 'vip'),
          findsOneWidget,
          reason: 'labelId hidratado',
        );
        expect(find.byKey(const Key('trigger_edit.label_id')), findsOneWidget);
        expect(find.byKey(const Key('trigger_edit.keyword')), findsNothing);
      },
    );

    testWidgets('delete con confirmación dispatcha DeleteRequested', (
      tester,
    ) async {
      await pumpHost(tester, editing: _textTrigger());

      // Tap del botón delete.
      await tester.tap(find.byKey(const Key('trigger_edit.delete')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('trigger_edit.delete_confirm')),
        findsOneWidget,
      );

      // Confirma.
      await tester.tap(find.byKey(const Key('trigger_edit.delete_confirm.ok')));
      await tester.pumpAndSettle();

      verify(
        () => triggers.add(const TriggersDeleteRequested(triggerId: 't1')),
      ).called(1);
    });

    testWidgets('delete-confirm cancelado NO dispatcha', (tester) async {
      await pumpHost(tester, editing: _textTrigger());

      await tester.tap(find.byKey(const Key('trigger_edit.delete')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('trigger_edit.delete_confirm.cancel')),
      );
      await tester.pumpAndSettle();

      verifyNever(() => triggers.add(any()));
    });

    testWidgets('add-mode NO muestra el botón delete', (tester) async {
      await pumpHost(tester);
      expect(find.byKey(const Key('trigger_edit.delete')), findsNothing);
    });

    testWidgets(
      'submit edit dispatcha UpdateRequested con documento completo (PUT semantics)',
      (tester) async {
        // Trigger inicial isActive=true, keyword="menu". Cambiamos
        // keyword y dejamos isActive sin tocar — PUT debe llevar isActive
        // explícito (no omitido) para no reaplicar el default true.
        await pumpHost(tester, editing: _textTrigger(isActive: false));

        await tester.enterText(
          find.byKey(const Key('trigger_edit.keyword')),
          'hola',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('trigger_edit.submit')));
        await tester.pump();

        verify(
          () => triggers.add(
            const TriggersUpdateRequested(
              triggerId: 't1',
              triggerType: TriggerType.text,
              matchType: MatchType.contains,
              keyword: 'hola',
              labelId: '',
              labelAction: null,
              scope: TriggerScope.both,
              // Preserva el isActive=false original: si lo omitiéramos el
              // backend reactivaría el trigger.
              isActive: false,
            ),
          ),
        ).called(1);
      },
    );
  });

  group('TriggerEditSheet · failure copy', () {
    testWidgets(
      'MutationFailed(Invalid) muestra copy específico para revisar datos',
      (tester) async {
        whenListen(
          triggers,
          Stream<TriggersState>.fromIterable(<TriggersState>[
            const TriggersMutationFailed(<Trigger>[], TriggersInvalidFailure()),
          ]),
          initialState: const TriggersLoaded(<Trigger>[]),
        );
        await pumpHost(tester);
        await tester.pump();

        expect(
          find.byKey(const Key('trigger_edit.error.invalid')),
          findsOneWidget,
        );
      },
    );

    testWidgets('MutationFailed(Network) muestra copy de red', (tester) async {
      whenListen(
        triggers,
        Stream<TriggersState>.fromIterable(<TriggersState>[
          const TriggersMutationFailed(<Trigger>[], TriggersNetworkFailure()),
        ]),
        initialState: const TriggersLoaded(<Trigger>[]),
      );
      await pumpHost(tester);
      await tester.pump();

      expect(
        find.byKey(const Key('trigger_edit.error.network')),
        findsOneWidget,
      );
    });

    testWidgets(
      'MutationFailed(NotFound) en edit muestra copy "ya no existe"',
      (tester) async {
        whenListen(
          triggers,
          Stream<TriggersState>.fromIterable(<TriggersState>[
            const TriggersMutationFailed(
              <Trigger>[],
              TriggersNotFoundFailure(),
            ),
          ]),
          initialState: const TriggersLoaded(<Trigger>[]),
        );
        await pumpHost(tester, editing: _textTrigger());
        await tester.pump();

        expect(
          find.byKey(const Key('trigger_edit.error.notfound')),
          findsOneWidget,
        );
      },
    );
  });

  group('TriggerEditSheet · auto-pop on success', () {
    testWidgets('tras submit exitoso → estado Loaded pop-ea el sheet', (
      tester,
    ) async {
      // Controlamos el stream del bloc manualmente para emitir
      // estados en el orden y momento que el test pida — usar
      // Stream.fromIterable los emite todos antes de que el sheet
      // monte y _didSubmit alcance a quedar en true.
      final controller = StreamController<TriggersState>.broadcast();
      addTearDown(controller.close);
      var current = const TriggersLoaded(<Trigger>[]) as TriggersState;
      when(() => triggers.state).thenAnswer((_) => current);
      whenListen(triggers, controller.stream, initialState: current);

      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scoped = _flow();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: BlocProvider<TriggersBloc>.value(
            value: triggers,
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (rootCtx) => Scaffold(
                  body: Builder(
                    builder: (innerCtx) => ElevatedButton(
                      child: const Text('open'),
                      onPressed: () => showModalBottomSheet<void>(
                        context: innerCtx,
                        builder: (_) => TriggerEditSheet(scopedFlow: scoped),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo disparador'), findsOneWidget);

      // Llena keyword + submit (dispara _didSubmit; flowId viene del
      // scopedFlow, sin dropdown).
      await tester.enterText(
        find.byKey(const Key('trigger_edit.keyword')),
        'hola',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('trigger_edit.submit')));
      await tester.pump();

      // Ahora simulo la cadena Mutating → Loading → Loaded del bloc.
      current = const TriggersMutating(<Trigger>[]);
      controller.add(current);
      await tester.pump();
      current = const TriggersLoading();
      controller.add(current);
      await tester.pump();
      current = TriggersLoaded(<Trigger>[
        _textTrigger(id: 'new', keyword: 'hola'),
      ]);
      controller.add(current);
      await tester.pumpAndSettle();

      expect(find.text('Nuevo disparador'), findsNothing);
    });

    testWidgets('Loaded ANTES del submit NO cierra el sheet (sin _didSubmit)', (
      tester,
    ) async {
      // El sheet arranca con estado Loaded vigente; si popeara siempre
      // con Loaded, no podría ni montarse. _didSubmit gate-a el pop.
      await pumpHost(tester);
      expect(find.text('Nuevo disparador'), findsOneWidget);
    });
  });
}
