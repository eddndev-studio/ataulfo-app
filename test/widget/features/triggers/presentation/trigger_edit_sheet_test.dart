import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_choice_chip.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/core/design/widgets/app_switch.dart';
import 'package:ataulfo/features/flows/domain/entities/flow.dart' as fdom;
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/failures/labels_failure.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_bloc.dart';
import 'package:ataulfo/features/triggers/domain/entities/trigger.dart';
import 'package:ataulfo/features/triggers/domain/failures/triggers_failure.dart';
import 'package:ataulfo/features/triggers/presentation/bloc/triggers_bloc.dart';
import 'package:ataulfo/features/triggers/presentation/widgets/trigger_edit_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTriggersBloc extends MockBloc<TriggersEvent, TriggersState>
    implements TriggersBloc {}

class _MockLabelsBloc extends MockBloc<LabelsEvent, LabelsState>
    implements LabelsBloc {}

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

Label _lbl({
  String id = 'vip',
  String name = 'VIP',
  String color = '#FF8800',
}) => Label(id: id, name: name, color: color, description: '');

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
    registerFallbackValue(const LabelsLoadRequested());
  });

  late _MockTriggersBloc triggers;
  late _MockLabelsBloc labels;

  setUp(() {
    triggers = _MockTriggersBloc();
    when(() => triggers.state).thenReturn(const TriggersLoaded(<Trigger>[]));
    labels = _MockLabelsBloc();
    // Catálogo poblado por default; los tests de loading/error/empty lo
    // sobrescriben.
    when(() => labels.state).thenReturn(
      LabelsLoaded(<Label>[
        _lbl(id: 'vip', name: 'VIP'),
        _lbl(id: 'lead', name: 'Lead', color: '#33AAFF'),
      ]),
    );
  });

  // El sheet completo con todos los controles supera el viewport
  // default de flutter_test (800x600). pumpHost agranda y restaura.
  Future<void> pumpHost(
    WidgetTester tester, {
    Trigger? editing,
    fdom.Flow? scopedFlow,
    LabelsState? labelsState,
  }) async {
    if (labelsState != null) {
      when(() => labels.state).thenReturn(labelsState);
    }
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
            BlocProvider<LabelsBloc>.value(value: labels),
          ],
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

  group('UX del sheet (barrido)', () {
    testWidgets('con teclado abierto el sheet aplica el inset inferior', (
      tester,
    ) async {
      // Simula el teclado: el sheet DEBE reaccionar por sí mismo al
      // viewInsets (el padre lo abría con un inset congelado al momento de
      // abrir, que nunca se actualizaba al aparecer el teclado).
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<TriggersBloc>.value(value: triggers),
              BlocProvider<LabelsBloc>.value(value: labels),
            ],
            // El MediaQuery vive DENTRO del Scaffold: el Scaffold consume el
            // viewInsets de su body (resize), pero un bottom sheet real vive
            // en el overlay y SÍ ve el inset del teclado.
            child: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(
                  viewInsets: EdgeInsets.only(bottom: 300),
                ),
                child: TriggerEditSheet(scopedFlow: _flow()),
              ),
            ),
          ),
        ),
      );

      final padding = find.byWidgetPredicate(
        (w) =>
            w is Padding &&
            w.padding.resolve(TextDirection.ltr).bottom >= 300 &&
            w.child is SingleChildScrollView,
      );
      expect(padding, findsOneWidget);
    });

    testWidgets('las opciones del LabelPicker dan área táctil ≥44px', (
      tester,
    ) async {
      await pumpHost(tester, editing: _labelTrigger(labelId: 'vip'));

      final option = find.byKey(
        const Key('trigger_edit.label_picker.option.vip'),
      );
      expect(option, findsOneWidget);
      expect(
        tester.getSize(option).height,
        greaterThanOrEqualTo(44.0),
        reason: 'una fila de 36px es difícil de acertar con el pulgar',
      );
    });

    testWidgets('los pickers usan AppChoiceChip (Semantics + área táctil)', (
      tester,
    ) async {
      await pumpHost(tester);

      // Migrados del par AppPill+InkWell (sin Semantics de botón y con el
      // seleccionado inerte) al chip controlado del design system.
      expect(find.byType(AppChoiceChip), findsWidgets);
      expect(find.byType(AppPill), findsNothing);
    });
  });

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

  group('TriggerEditSheet (Add mode · LABEL · selector)', () {
    testWidgets(
      'cambiar a LABEL oculta keyword/match/scope y muestra el selector + labelAction',
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
        // El campo de id crudo ya no existe; en su lugar el selector.
        expect(find.byKey(const Key('trigger_edit.label_id')), findsNothing);
        expect(
          find.byKey(const Key('trigger_edit.label_picker')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('trigger_edit.label_action_picker')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'el selector renderiza una opción por label del catálogo (nombre)',
      (tester) async {
        await pumpHost(tester);
        await tester.tap(find.text('Etiqueta'));
        await tester.pump();

        expect(
          find.byKey(const Key('trigger_edit.label_picker.option.vip')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('trigger_edit.label_picker.option.lead')),
          findsOneWidget,
        );
        expect(find.text('VIP'), findsOneWidget);
        expect(find.text('Lead'), findsOneWidget);
      },
    );

    testWidgets(
      'elegir una opción + submit → AddRequested con el labelId correcto',
      (tester) async {
        await pumpHost(tester);

        await tester.tap(find.text('Etiqueta'));
        await tester.pump();
        await tester.tap(
          find.byKey(const Key('trigger_edit.label_picker.option.vip')),
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

    testWidgets('submit LABEL sin elegir etiqueta es no-op', (tester) async {
      await pumpHost(tester);

      await tester.tap(find.text('Etiqueta'));
      await tester.pump();
      // Sin tap en ninguna opción.
      await tester.tap(find.byKey(const Key('trigger_edit.submit')));
      await tester.pump();

      verifyNever(() => triggers.add(any()));
    });

    testWidgets('elegir opción marca la selección (check)', (tester) async {
      await pumpHost(tester);
      await tester.tap(find.text('Etiqueta'));
      await tester.pump();

      expect(
        find.byKey(const Key('trigger_edit.label_picker.selected')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const Key('trigger_edit.label_picker.option.lead')),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('trigger_edit.label_picker.selected')),
        findsOneWidget,
      );
    });

    testWidgets(
      'tras elegir etiqueta y volver a TEXT, el submit TEXT no arrastra labelId',
      (tester) async {
        await pumpHost(tester);

        // LABEL: elige una etiqueta.
        await tester.tap(find.text('Etiqueta'));
        await tester.pump();
        await tester.tap(
          find.byKey(const Key('trigger_edit.label_picker.option.vip')),
        );
        await tester.pump();

        // Vuelve a TEXT y crea un trigger de texto.
        await tester.tap(find.text('Texto'));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('trigger_edit.keyword')),
          'hola',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('trigger_edit.submit')));
        await tester.pump();

        // El labelId elegido no debe filtrarse al payload TEXT.
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

  group('TriggerEditSheet (LABEL · estados del catálogo)', () {
    testWidgets('LabelsLoading muestra el spinner del picker', (tester) async {
      await pumpHost(tester, labelsState: const LabelsLoading());
      await tester.tap(find.text('Etiqueta'));
      await tester.pump();

      expect(
        find.byKey(const Key('trigger_edit.label_picker.loading')),
        findsOneWidget,
      );
    });

    testWidgets(
      'LabelsFailed muestra error + reintento; el retry redispatcha LabelsLoadRequested',
      (tester) async {
        await pumpHost(
          tester,
          labelsState: const LabelsFailed(LabelsNetworkFailure()),
        );
        await tester.tap(find.text('Etiqueta'));
        await tester.pump();

        expect(
          find.byKey(const Key('trigger_edit.label_picker.error')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('trigger_edit.label_picker.retry')),
        );
        await tester.pump();

        verify(() => labels.add(const LabelsLoadRequested())).called(1);
      },
    );

    testWidgets('Loaded vacío muestra empty state y el submit queda no-op', (
      tester,
    ) async {
      await pumpHost(tester, labelsState: const LabelsLoaded(<Label>[]));
      await tester.tap(find.text('Etiqueta'));
      await tester.pump();

      expect(
        find.byKey(const Key('trigger_edit.label_picker.empty')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('trigger_edit.submit')));
      await tester.pump();
      verifyNever(() => triggers.add(any()));
    });

    testWidgets('un fallo cargando labels NO bloquea un disparador TEXT', (
      tester,
    ) async {
      // El catálogo está en error, pero el operador crea un trigger
      // TEXT: el path TEXT no consume el selector y debe poder enviar.
      await pumpHost(
        tester,
        labelsState: const LabelsFailed(LabelsNetworkFailure()),
      );

      await tester.enterText(
        find.byKey(const Key('trigger_edit.keyword')),
        'hola',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('trigger_edit.submit')));
      await tester.pump();

      verify(() => triggers.add(any())).called(1);
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
      'LABEL trigger: preselecciona la opción del catálogo (submit la preserva)',
      (tester) async {
        await pumpHost(tester, editing: _labelTrigger(labelId: 'vip'));

        // Sin tocar nada, el submit debe llevar el labelId hidratado.
        expect(find.byKey(const Key('trigger_edit.keyword')), findsNothing);
        expect(
          find.byKey(const Key('trigger_edit.label_picker.selected')),
          findsOneWidget,
          reason: 'la opción del labelId vigente queda marcada',
        );
        // No hay fallback de desconocido cuando el id sí está en el catálogo.
        expect(
          find.byKey(const Key('trigger_edit.label_picker.unknown')),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('trigger_edit.submit')));
        await tester.pump();

        verify(
          () => triggers.add(
            const TriggersUpdateRequested(
              triggerId: 't2',
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

    testWidgets(
      'LABEL con labelId ausente del catálogo → fallback "desconocida" + id crudo; submit lo preserva',
      (tester) async {
        await pumpHost(
          tester,
          editing: _labelTrigger(labelId: 'ghost'),
          labelsState: LabelsLoaded(<Label>[_lbl(id: 'vip', name: 'VIP')]),
        );

        // El fallback orienta a la acción correctiva; el UUID crudo es ruido
        // para el operador (el id NO se descarta: el submit lo preserva).
        expect(
          find.byKey(const Key('trigger_edit.label_picker.unknown')),
          findsOneWidget,
        );
        expect(find.textContaining('ghost'), findsNothing);
        expect(
          find.text('Fue eliminada del catálogo. Elige otra etiqueta.'),
          findsOneWidget,
        );

        // El operador puede guardar otros campos sin perder el id original.
        await tester.tap(find.byKey(const Key('trigger_edit.submit')));
        await tester.pump();

        verify(
          () => triggers.add(
            const TriggersUpdateRequested(
              triggerId: 't2',
              triggerType: TriggerType.label,
              matchType: null,
              keyword: '',
              labelId: 'ghost',
              labelAction: LabelAction.add,
              scope: TriggerScope.both,
              isActive: true,
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('delete con confirmación dispatcha DeleteRequested', (
      tester,
    ) async {
      await pumpHost(tester, editing: _textTrigger());

      // Tap del botón delete.
      await tester.tap(find.byKey(const Key('trigger_edit.delete')));
      await tester.pumpAndSettle();

      // El diálogo se ancla por su botón de confirmar: el helper canónico
      // (showAppConfirmDialog) no expone key en el AlertDialog mismo.
      expect(
        find.byKey(const Key('trigger_edit.delete_confirm.ok')),
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
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<TriggersBloc>.value(value: triggers),
              BlocProvider<LabelsBloc>.value(value: labels),
            ],
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (rootCtx) => Scaffold(
                  body: Builder(
                    builder: (innerCtx) => ElevatedButton(
                      child: const Text('open'),
                      onPressed: () => showModalBottomSheet<void>(
                        context: innerCtx,
                        builder: (_) => MultiBlocProvider(
                          providers: <BlocProvider<dynamic>>[
                            BlocProvider<TriggersBloc>.value(value: triggers),
                            BlocProvider<LabelsBloc>.value(value: labels),
                          ],
                          child: TriggerEditSheet(scopedFlow: scoped),
                        ),
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
