import 'dart:async';
import 'dart:convert';

import 'package:ataulfo/core/design/app_bottom_sheet.dart';
import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_choice_chip.dart';
import 'package:ataulfo/core/design/widgets/app_slider.dart';
import 'package:ataulfo/features/flows/domain/entities/step.dart' as fdom;
import 'package:ataulfo/features/flows/domain/failures/flows_failure.dart';
import 'package:ataulfo/features/flows/presentation/bloc/flow_steps_bloc.dart';
import 'package:ataulfo/features/flows/presentation/widgets/step_edit_sheet.dart';
import 'package:ataulfo/features/flows/presentation/widgets/step_editor_launcher.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/repositories/labels_repository.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_bloc.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<FlowStepsEvent, FlowStepsState>
    implements FlowStepsBloc {}

/// Steps TEXT fixture para los flujos del condicional: candidatos a
/// destino en distintos arreglos (Add: orders 0/1; Edit: 1/2 tras el CT).
const _tHola = fdom.Step(
  id: 't-hola',
  flowId: 'f1',
  type: fdom.StepType.text,
  order: 0,
  content: 'Hola',
  mediaRef: '',
  metadataJson: '{}',
  delayMs: 1000,
  jitterPct: 0,
  aiOnly: false,
);
const _tCerrados = fdom.Step(
  id: 't-cerrados',
  flowId: 'f1',
  type: fdom.StepType.text,
  order: 1,
  content: 'Cerrados',
  mediaRef: '',
  metadataJson: '{}',
  delayMs: 1000,
  jitterPct: 0,
  aiOnly: false,
);
const _tHolaAt1 = fdom.Step(
  id: 't-hola',
  flowId: 'f1',
  type: fdom.StepType.text,
  order: 1,
  content: 'Hola',
  mediaRef: '',
  metadataJson: '{}',
  delayMs: 1000,
  jitterPct: 0,
  aiOnly: false,
);
const _tCerradosAt2 = fdom.Step(
  id: 't-cerrados',
  flowId: 'f1',
  type: fdom.StepType.text,
  order: 2,
  content: 'Cerrados',
  mediaRef: '',
  metadataJson: '{}',
  delayMs: 1000,
  jitterPct: 0,
  aiOnly: false,
);

class _MockLabelsBloc extends MockBloc<LabelsEvent, LabelsState>
    implements LabelsBloc {}

Label _lbl({
  String id = 'vip',
  String name = 'VIP',
  String color = '#FF8800',
}) => Label(id: id, name: name, color: color, description: '');

/// Asset de prueba con un content-type/filename dado; la previewUrl difiere del
/// ref para verificar que sólo el ref BARE (y el filename) se persisten.
MediaAsset _asset(
  String ref, {
  String ct = 'image/png',
  String filename = 'file.png',
}) => MediaAsset(
  ref: ref,
  previewUrl: 'https://signed/$ref?sig=ephemeral',
  filename: filename,
  contentType: ct,
  size: 1,
  createdAt: DateTime.utc(2026, 1, 1),
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

  late _MockBloc bloc;
  late _MockLabelsBloc labels;

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.state).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));
    labels = _MockLabelsBloc();
    // Catálogo poblado por default; los tests que ejercen estados del catálogo
    // lo sobrescriben vía `labelsState`.
    when(
      () => labels.state,
    ).thenReturn(LabelsLoaded(<Label>[_lbl(id: 'vip', name: 'VIP')]));
  });

  // El sheet con todos los controles + form CONDITIONAL_TIME (chip
  // picker + ventanas con time pickers + dropdowns) supera el viewport
  // default de flutter_test (800x600). `pumpHost` agranda y restaura.
  //
  // [createType] es el tipo elegido en el selector del primer tiempo (el
  // sheet ya no ofrece cambiar de tipo). [pickMediaRef] cablea el selector
  // de multimedia; null ⇒ read-only, el sheet sigue testeable aislado.
  Future<void> pumpHost(
    WidgetTester tester, {
    fdom.Step? editing,
    fdom.StepType createType = fdom.StepType.text,
    MediaRefPicker? pickMediaRef,
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
            BlocProvider<FlowStepsBloc>.value(value: bloc),
            BlocProvider<LabelsBloc>.value(value: labels),
          ],
          child: Scaffold(
            body: SafeArea(
              child: StepEditSheet(
                // El tipo se fija en initState (en producción cada sheet es
                // un modal recién montado); la key fuerza un State nuevo
                // cuando un mismo test re-pumpea con otro tipo.
                key: ValueKey<String>('${editing?.id}·${createType.name}'),
                editing: editing,
                createType: editing == null ? createType : null,
                pickMediaRef: pickMediaRef,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Expande el disclosure "Opciones de envío" (colapsado por default): los
  // controles de retraso/variación/modo viven dentro.
  Future<void> openSendOptions(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('step_edit.send_options')));
    await tester.tap(find.byKey(const Key('step_edit.send_options')));
    await tester.pumpAndSettle();
  }

  const editingStep = fdom.Step(
    id: 's1',
    flowId: 'f1',
    type: fdom.StepType.text,
    order: 0,
    content: 'Hola original',
    mediaRef: '',
    metadataJson: '{}',
    delayMs: 1500,
    jitterPct: 10,
    aiOnly: true,
  );

  group('StepEditSheet (Add mode)', () {
    testWidgets(
      'el header nombra el tipo elegido: "Nuevo paso · Texto"; el campo '
      'principal va primero y las opciones de envío viven colapsadas',
      (tester) async {
        await pumpHost(tester);

        expect(find.text('Nuevo paso · Texto'), findsOneWidget);
        expect(find.byKey(const Key('step_edit.content')), findsOneWidget);
        expect(find.byKey(const Key('step_edit.send_options')), findsOneWidget);
        // Colapsado: ni retraso, ni variación, ni chips de modo a la vista.
        expect(find.byKey(const Key('step_edit.delay.value')), findsNothing);
        expect(find.byKey(const Key('step_edit.jitter')), findsNothing);
        expect(find.byKey(const Key('step_edit.mode.always')), findsNothing);
        expect(find.byKey(const Key('step_edit.submit')), findsOneWidget);
      },
    );

    testWidgets(
      'expandir "Opciones de envío" revela retraso (slider con readout), '
      'variación y modo',
      (tester) async {
        await pumpHost(tester);
        await openSendOptions(tester);

        expect(find.byType(AppSlider), findsOneWidget);
        expect(find.byKey(const Key('step_edit.delay.slider')), findsOneWidget);
        expect(find.byKey(const Key('step_edit.delay.value')), findsOneWidget);
        expect(find.byKey(const Key('step_edit.jitter')), findsOneWidget);
        expect(find.byKey(const Key('step_edit.mode.always')), findsOneWidget);
        expect(find.byKey(const Key('step_edit.mode.ai')), findsOneWidget);
        expect(find.byKey(const Key('step_edit.mode.manual')), findsOneWidget);
      },
    );

    testWidgets(
      'submit con content vacío es no-op (no dispatcha AddRequested)',
      (tester) async {
        await pumpHost(tester);

        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        verifyNever(() => bloc.add(any()));
      },
    );

    testWidgets(
      'submit con content válido dispatcha AddRequested con los valores ingresados',
      (tester) async {
        await pumpHost(tester);

        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'Hola {{name}}',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        verify(
          () => bloc.add(
            const FlowStepsAddRequested(
              content: 'Hola {{name}}',
              delayMs: 1000,
              jitterPct: 0,
              aiOnly: false,
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'elegir "Solo disparadores" manda manualOnly:true (y aiOnly:false)',
      (tester) async {
        await pumpHost(tester);

        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'Promo',
        );
        await tester.pump();
        await openSendOptions(tester);
        await tester.ensureVisible(
          find.byKey(const Key('step_edit.mode.manual')),
        );
        await tester.tap(find.byKey(const Key('step_edit.mode.manual')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        final captured = verify(() => bloc.add(captureAny())).captured;
        final ev = captured.single as FlowStepsAddRequested;
        expect(ev.manualOnly, isTrue);
        expect(ev.aiOnly, isFalse);
      },
    );

    testWidgets(
      'los modos son excluyentes: pasar de "Solo IA" a "Solo disparadores" '
      'apaga aiOnly',
      (tester) async {
        await pumpHost(tester);

        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'Promo',
        );
        await tester.pump();
        await openSendOptions(tester);
        await tester.ensureVisible(find.byKey(const Key('step_edit.mode.ai')));
        await tester.tap(find.byKey(const Key('step_edit.mode.ai')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.mode.manual')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        final captured = verify(() => bloc.add(captureAny())).captured;
        final ev = captured.single as FlowStepsAddRequested;
        expect(ev.aiOnly, isFalse);
        expect(ev.manualOnly, isTrue);
      },
    );

    testWidgets(
      'nuevo paso arranca con delay 1s (no 0) y submit manda delayMs=1000',
      (tester) async {
        await pumpHost(tester);

        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'Hola',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        final captured = verify(() => bloc.add(captureAny())).captured;
        final ev = captured.single as FlowStepsAddRequested;
        expect(ev.delayMs, 1000);
      },
    );

    testWidgets(
      'arrastrar el slider de retraso al tope manda delayMs=60000 (1 min) y '
      'el readout acompaña ("1 min")',
      (tester) async {
        await pumpHost(tester);

        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'Hi',
        );
        await tester.pump();
        await openSendOptions(tester);
        await tester.ensureVisible(
          find.byKey(const Key('step_edit.delay.slider')),
        );
        // Más allá del ancho del control → clava en el máximo (60 s).
        await tester.drag(
          find.byKey(const Key('step_edit.delay.slider')),
          const Offset(2000, 0),
        );
        await tester.pump();

        final readout = tester.widget<Text>(
          find.byKey(const Key('step_edit.delay.value')),
        );
        expect(readout.data, '1 min');

        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        final captured = verify(() => bloc.add(captureAny())).captured;
        final ev = captured.single as FlowStepsAddRequested;
        expect(ev.delayMs, 60000);
      },
    );

    testWidgets(
      'la caption del retraso anuncia el rango del slider (1 s a 1 min) y '
      'sin valores fuera de rango no hay caption legacy',
      (tester) async {
        await pumpHost(tester);

        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'Hi',
        );
        await tester.pump();
        await openSendOptions(tester);

        expect(
          find.text(
            'Cuánto espera el Asistente antes de enviar el paso '
            '(1 s a 1 min).',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('step_edit.delay.legacy_range')),
          findsNothing,
        );
      },
    );

    testWidgets('la variación es un campo numérico: 15 → jitterPct 15', (
      tester,
    ) async {
      await pumpHost(tester);

      await tester.enterText(find.byKey(const Key('step_edit.content')), 'Hi');
      await tester.pump();
      await openSendOptions(tester);
      await tester.ensureVisible(find.byKey(const Key('step_edit.jitter')));
      await tester.enterText(find.byKey(const Key('step_edit.jitter')), '15');
      await tester.pump();
      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      final captured = verify(() => bloc.add(captureAny())).captured;
      final ev = captured.single as FlowStepsAddRequested;
      expect(ev.jitterPct, 15);
    });

    testWidgets('variación fuera de rango (>100) marca error y gatea submit', (
      tester,
    ) async {
      await pumpHost(tester);

      await tester.enterText(find.byKey(const Key('step_edit.content')), 'Hi');
      await tester.pump();
      await openSendOptions(tester);
      await tester.ensureVisible(find.byKey(const Key('step_edit.jitter')));
      await tester.enterText(find.byKey(const Key('step_edit.jitter')), '150');
      await tester.pump();

      expect(find.text('La variación va de 0 a 100.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      verifyNever(() => bloc.add(any()));
    });

    testWidgets(
      'editar un paso legacy con delay 0 lo sube al piso (1s) al guardar',
      (tester) async {
        const legacy = fdom.Step(
          id: 's-legacy',
          flowId: 'f1',
          type: fdom.StepType.text,
          order: 0,
          content: 'old',
          mediaRef: '',
          metadataJson: '{}',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        );
        when(
          () => bloc.state,
        ).thenReturn(const FlowStepsLoaded(<fdom.Step>[legacy]));
        await pumpHost(tester, editing: legacy);

        // Cambia solo el content; el delay legacy 0 se cura al piso al guardar.
        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'nuevo',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        final captured = verify(() => bloc.add(captureAny())).captured;
        final ev = captured.single as FlowStepsUpdateRequested;
        expect(ev.delayMs, 1000);
      },
    );

    testWidgets(
      'delay legacy 0: las opciones de envío abren EXPANDIDAS con el aviso '
      'honesto de la curación',
      (tester) async {
        const legacy = fdom.Step(
          id: 's-legacy',
          flowId: 'f1',
          type: fdom.StepType.text,
          order: 0,
          content: 'old',
          mediaRef: '',
          metadataJson: '{}',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        );
        when(
          () => bloc.state,
        ).thenReturn(const FlowStepsLoaded(<fdom.Step>[legacy]));
        await pumpHost(tester, editing: legacy);
        await tester.pumpAndSettle();

        // Sin tocar el disclosure: los controles ya están a la vista…
        expect(find.byKey(const Key('step_edit.delay.value')), findsOneWidget);
        // …junto con el aviso de que guardar ajustará el retraso al mínimo.
        expect(
          find.byKey(const Key('step_edit.legacy_delay_notice')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Este paso enviaba sin retraso'),
          findsOneWidget,
        );
      },
    );

    testWidgets('un paso con delay normal NO muestra el aviso de curación', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(const FlowStepsLoaded(<fdom.Step>[editingStep]));
      await pumpHost(tester, editing: editingStep);

      expect(find.byKey(const Key('step_edit.delay.value')), findsNothing);
      expect(
        find.byKey(const Key('step_edit.legacy_delay_notice')),
        findsNothing,
      );
    });

    // Un retraso guardado por encima del tope del slider (el backend admite
    // hasta 5 min): el control pinta clavado al máximo, el readout dice el
    // valor REAL y una caption explica que arrastrar lo reemplaza.
    const legacyLong = fdom.Step(
      id: 's-long',
      flowId: 'f1',
      type: fdom.StepType.text,
      order: 0,
      content: 'lento',
      mediaRef: '',
      metadataJson: '{}',
      delayMs: 300000,
      jitterPct: 0,
      aiOnly: false,
    );

    testWidgets(
      'delay legado > 1 min: slider clavado al máximo, readout con el valor '
      'REAL ("5 min") y caption quieta explicando cómo cambiarlo',
      (tester) async {
        when(
          () => bloc.state,
        ).thenReturn(const FlowStepsLoaded(<fdom.Step>[legacyLong]));
        await pumpHost(tester, editing: legacyLong);
        await openSendOptions(tester);

        final readout = tester.widget<Text>(
          find.byKey(const Key('step_edit.delay.value')),
        );
        expect(readout.data, '5 min');

        final slider = tester.widget<AppSlider>(
          find.byKey(const Key('step_edit.delay.slider')),
        );
        expect(slider.value, slider.max);

        expect(
          find.byKey(const Key('step_edit.delay.legacy_range')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'delay legado > 1 min se CONSERVA al guardar si el slider no se toca: '
      'cambiar solo el content no manda delayMs',
      (tester) async {
        when(
          () => bloc.state,
        ).thenReturn(const FlowStepsLoaded(<fdom.Step>[legacyLong]));
        await pumpHost(tester, editing: legacyLong);

        // El slider llega a construirse (pintado clavado al máximo): ese
        // clamp de pintado NO debe emitir onDelayChanged por sí solo.
        await openSendOptions(tester);
        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'nuevo',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        final captured = verify(() => bloc.add(captureAny())).captured;
        final ev = captured.single as FlowStepsUpdateRequested;
        expect(ev.content, 'nuevo');
        // El valor exacto (5 min) sobrevive: no viaja delayMs en el PATCH.
        expect(ev.delayMs, isNull);
      },
    );

    testWidgets(
      'arrastrar el slider de un delay legado > 1 min lo trae al rango: '
      'al mínimo → delayMs 1000',
      (tester) async {
        when(
          () => bloc.state,
        ).thenReturn(const FlowStepsLoaded(<fdom.Step>[legacyLong]));
        await pumpHost(tester, editing: legacyLong);
        await openSendOptions(tester);

        await tester.ensureVisible(
          find.byKey(const Key('step_edit.delay.slider')),
        );
        await tester.drag(
          find.byKey(const Key('step_edit.delay.slider')),
          const Offset(-2000, 0),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        final captured = verify(() => bloc.add(captureAny())).captured;
        final ev = captured.single as FlowStepsUpdateRequested;
        expect(ev.delayMs, 1000);
      },
    );

    testWidgets(
      'estado Mutating bloquea el submit (tap no dispatcha AddRequested)',
      (tester) async {
        when(
          () => bloc.state,
        ).thenReturn(const FlowStepsMutating(<fdom.Step>[]));

        await pumpHost(tester);
        await tester.enterText(find.byKey(const Key('step_edit.content')), 'X');
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        verifyNever(() => bloc.add(any()));
      },
    );

    testWidgets(
      'MutationFailed con InvalidStepFailure muestra copy específico',
      (tester) async {
        when(() => bloc.state).thenReturn(
          const FlowStepsMutationFailed(
            <fdom.Step>[],
            FlowsInvalidStepFailure(),
          ),
        );

        await pumpHost(tester);

        expect(
          find.byKey(const Key('step_edit.error.invalid_step')),
          findsOneWidget,
        );
      },
    );

    testWidgets('MutationFailed con NetworkFailure muestra copy de red', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const FlowStepsMutationFailed(<fdom.Step>[], FlowsNetworkFailure()),
      );

      await pumpHost(tester);

      expect(find.byKey(const Key('step_edit.error.network')), findsOneWidget);
    });
  });

  group('StepEditSheet (Add mode · multimedia)', () {
    testWidgets(
      'crear con tipo multimedia muestra el selector de recurso; con TEXT no',
      (tester) async {
        await pumpHost(tester, createType: fdom.StepType.image);
        expect(find.text('Nuevo paso · Imagen'), findsOneWidget);
        expect(find.byKey(const Key('step_edit.media_picker')), findsOneWidget);

        await pumpHost(tester);
        expect(find.byKey(const Key('step_edit.media_picker')), findsNothing);
      },
    );

    testWidgets(
      'elegir un asset vía el picker y submit dispatcha AddRequested con el '
      'ref BARE devuelto (caption vacío)',
      (tester) async {
        // El picker fake devuelve el `ref` BARE canónico. El evento
        // despachado DEBE llevar exactamente ese ref — re-pinea el
        // linchpin a nivel del sheet: lo que se persiste es el ref BARE.
        const bareRef = 'tenant/org1/media/abc123.png';
        await pumpHost(
          tester,
          createType: fdom.StepType.image,
          pickMediaRef: (_, _) async => _asset(bareRef),
        );

        await tester.tap(find.byKey(const Key('step_edit.media_picker')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        verify(
          () => bloc.add(
            const FlowStepsAddRequested(
              type: fdom.StepType.image,
              mediaRef: bareRef,
              content: '',
              delayMs: 1000,
              jitterPct: 0,
              aiOnly: false,
              // El nombre del archivo viaja junto con el ref para mostrarlo en
              // la lista de pasos (el _asset por default es 'file.png').
              metadataJson: '{"media_filename":"file.png"}',
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'DOCUMENT: el picker se abre SIN filtro de familia (cualquier archivo, '
      'p. ej. audio enviado como documento) y el filename viaja en media_filename',
      (tester) async {
        String? gotFamily = 'sentinel';
        await pumpHost(
          tester,
          createType: fdom.StepType.document,
          pickMediaRef: (_, family) async {
            gotFamily = family;
            return _asset(
              'tenant/org1/media/doc777.pdf',
              ct: 'application/pdf',
              filename: 'informe-q3.pdf',
            );
          },
        );

        await tester.tap(find.byKey(const Key('step_edit.media_picker')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        // DOCUMENT no filtra por familia: permite adjuntar cualquier asset
        // (incl. audio) para enviarlo como archivo descargable.
        expect(gotFamily, isNull);

        final captured = verify(() => bloc.add(captureAny())).captured;
        expect(captured, hasLength(1));
        final ev = captured.single as FlowStepsAddRequested;
        expect(ev.type, fdom.StepType.document);
        expect(ev.mediaRef, 'tenant/org1/media/doc777.pdf');
        // El nombre real del documento viaja en media_filename.
        expect(ev.metadataJson, isNotNull);
        final meta = jsonDecode(ev.metadataJson!) as Map<String, dynamic>;
        expect(meta['media_filename'], 'informe-q3.pdf');
      },
    );

    testWidgets(
      'IMAGE: escribe media_filename en el metadata (para mostrar el nombre del '
      'recurso en la lista de pasos)',
      (tester) async {
        await pumpHost(
          tester,
          createType: fdom.StepType.image,
          pickMediaRef: (_, _) async =>
              _asset('tenant/org1/media/foto.png', filename: 'foto.png'),
        );

        await tester.tap(find.byKey(const Key('step_edit.media_picker')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        final captured = verify(() => bloc.add(captureAny())).captured;
        final ev = captured.single as FlowStepsAddRequested;
        expect(ev.metadataJson, isNotNull);
        final meta = jsonDecode(ev.metadataJson!) as Map<String, dynamic>;
        expect(meta['media_filename'], 'foto.png');
      },
    );

    testWidgets('submit multimedia sin selección es no-op (gate del trim)', (
      tester,
    ) async {
      await pumpHost(
        tester,
        createType: fdom.StepType.image,
        pickMediaRef: (_, _) async => _asset('tenant/o/media/x.png'),
      );

      // Sin tocar el picker → _mediaCtrl sigue vacío.
      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      verifyNever(() => bloc.add(any()));
    });

    testWidgets(
      'cancelar el picker (devuelve null) no cambia nada; submit sigue no-op',
      (tester) async {
        await pumpHost(
          tester,
          createType: fdom.StepType.image,
          pickMediaRef: (_, _) async => null,
        );

        await tester.tap(find.byKey(const Key('step_edit.media_picker')));
        await tester.pump();

        // Sin ref seleccionado: el selector sigue presente y no hay chip.
        expect(find.byKey(const Key('step_edit.media_picker')), findsOneWidget);
        expect(find.byKey(const Key('step_edit.media_selected')), findsNothing);

        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        verifyNever(() => bloc.add(any()));
      },
    );
  });

  group('StepEditSheet (Edit mode)', () {
    setUpAll(() {
      registerFallbackValue(
        const FlowStepsUpdateRequested(stepId: 's', content: 'x'),
      );
    });

    testWidgets(
      'renderiza "Editar paso" con la identidad del tipo visible (pill) y '
      'el porqué de su inmutabilidad; prefill del content',
      (tester) async {
        await pumpHost(tester, editing: editingStep);

        expect(find.text('Editar paso'), findsOneWidget);
        // La identidad del objeto editado siempre visible: pill del tipo.
        expect(find.byKey(const Key('step_edit.type_pill')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('step_edit.type_pill')),
            matching: find.text('Texto'),
          ),
          findsOneWidget,
        );
        // El porqué del tipo fijo cabe en una caption discreta.
        expect(find.byKey(const Key('step_edit.type_caption')), findsOneWidget);
        // Ya no existe el muro de chips para cambiar el tipo.
        expect(find.byKey(const Key('step_edit.type.text')), findsNothing);
        expect(find.byKey(const Key('step_edit.type.image')), findsNothing);
        // El TextField está prefilled con el content del editing.
        final tf = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('step_edit.content')),
            matching: find.byType(TextField),
          ),
        );
        expect(tf.controller?.text, 'Hola original');
      },
    );

    testWidgets('crear NO muestra pill de tipo (el título ya lo nombra)', (
      tester,
    ) async {
      await pumpHost(tester);

      expect(find.byKey(const Key('step_edit.type_pill')), findsNothing);
      expect(find.byKey(const Key('step_edit.type_caption')), findsNothing);
    });

    testWidgets('edit con cambios dispatcha UpdateRequested con only-changed', (
      tester,
    ) async {
      await pumpHost(tester, editing: editingStep);
      // Cambia solo el content; retraso/variación/modo quedan iguales.
      await tester.enterText(
        find.byKey(const Key('step_edit.content')),
        'Hola edited',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      verify(
        () => bloc.add(
          const FlowStepsUpdateRequested(stepId: 's1', content: 'Hola edited'),
        ),
      ).called(1);
    });

    testWidgets('edit sin cambios es no-op (no dispatcha UpdateRequested)', (
      tester,
    ) async {
      await pumpHost(tester, editing: editingStep);
      // Sin tocar nada — sólo tap submit.
      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      verifyNever(() => bloc.add(any()));
    });

    testWidgets(
      'cambiar un paso "Solo IA" a "Solo disparadores" patchea ambos flags',
      (tester) async {
        // editingStep tiene aiOnly:true ⇒ el selector arranca en "Solo IA".
        await pumpHost(tester, editing: editingStep);

        await openSendOptions(tester);
        await tester.ensureVisible(
          find.byKey(const Key('step_edit.mode.manual')),
        );
        await tester.tap(find.byKey(const Key('step_edit.mode.manual')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        verify(
          () => bloc.add(
            const FlowStepsUpdateRequested(
              stepId: 's1',
              aiOnly: false,
              manualOnly: true,
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'volver el paso a "Siempre" apaga el flag activo sin tocar el otro',
      (tester) async {
        await pumpHost(tester, editing: editingStep);

        await openSendOptions(tester);
        await tester.ensureVisible(
          find.byKey(const Key('step_edit.mode.always')),
        );
        await tester.tap(find.byKey(const Key('step_edit.mode.always')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        // manualOnly ya era false ⇒ se omite del PATCH (only-changed).
        verify(
          () => bloc.add(
            const FlowStepsUpdateRequested(stepId: 's1', aiOnly: false),
          ),
        ).called(1);
      },
    );

    testWidgets('edit con content vacío es no-op (gate del trim().isEmpty)', (
      tester,
    ) async {
      await pumpHost(tester, editing: editingStep);
      await tester.enterText(find.byKey(const Key('step_edit.content')), '   ');
      await tester.pump();
      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      verifyNever(() => bloc.add(any()));
    });

    testWidgets(
      'modo edit muestra botón eliminar; tap → confirm → DeleteRequested',
      (tester) async {
        registerFallbackValue(const FlowStepsDeleteRequested('s'));

        await pumpHost(tester, editing: editingStep);
        expect(find.byKey(const Key('step_edit.delete')), findsOneWidget);

        await tester.tap(find.byKey(const Key('step_edit.delete')));
        await tester.pumpAndSettle();

        // El dialog de confirmación aparece — anclado por su botón de
        // confirmar: el helper canónico no expone key en el AlertDialog.
        expect(
          find.byKey(const Key('step_edit.delete_confirm.ok')),
          findsOneWidget,
        );
        // Tap en confirmar.
        await tester.tap(find.byKey(const Key('step_edit.delete_confirm.ok')));
        await tester.pumpAndSettle();

        verify(() => bloc.add(const FlowStepsDeleteRequested('s1'))).called(1);
      },
    );

    testWidgets('modo add no muestra botón eliminar', (tester) async {
      await pumpHost(tester);

      expect(find.byKey(const Key('step_edit.delete')), findsNothing);
    });

    testWidgets('tap en cancelar del dialog NO dispatcha DeleteRequested', (
      tester,
    ) async {
      await pumpHost(tester, editing: editingStep);
      await tester.tap(find.byKey(const Key('step_edit.delete')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('step_edit.delete_confirm.cancel')),
      );
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any()));
    });

    testWidgets(
      'paso destino de un condicional: el diálogo NO ofrece "Eliminar" — '
      'CTA única "Entendido" y nada se dispatcha',
      (tester) async {
        // Un CT del flujo apunta a editingStep (s1): la acción está condenada
        // al 409 y por eso no se ofrece.
        const ct = fdom.Step(
          id: 's-ct',
          flowId: 'f1',
          type: fdom.StepType.conditionalTime,
          order: 1,
          content: '',
          mediaRef: '',
          metadataJson:
              '{"tz":"UTC","windows":[{"days":[1],"from":"08:00",'
              '"to":"12:00"}],"on_match_step_id":"s1",'
              '"on_else_step_id":"t-cerrados"}',
          delayMs: 1000,
          jitterPct: 0,
          aiOnly: false,
        );
        when(() => bloc.state).thenReturn(
          const FlowStepsLoaded(<fdom.Step>[editingStep, ct, _tCerradosAt2]),
        );
        await pumpHost(tester, editing: editingStep);

        await tester.tap(find.byKey(const Key('step_edit.delete')));
        await tester.pumpAndSettle();

        // La acción condenada no se ofrece: no hay botón "Eliminar".
        expect(
          find.byKey(const Key('step_edit.delete_confirm.ok')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('step_edit.delete_blocked.ok')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('step_edit.delete_blocked.ok')));
        await tester.pumpAndSettle();

        verifyNever(() => bloc.add(any()));
        // El sheet sigue abierto: entender no es descartar el trabajo.
        expect(find.byKey(const Key('step_edit.submit')), findsOneWidget);
      },
    );
  });

  group('StepEditSheet (Edit mode · multimedia)', () {
    const imgStep = fdom.Step(
      id: 's-img',
      flowId: 'f1',
      type: fdom.StepType.image,
      order: 0,
      content: 'caption original',
      mediaRef: 'https://x/orig.png',
      metadataJson: '{}',
      // ≥1s: valor normal de un paso que envía al wire bajo el piso de delay.
      delayMs: 1000,
      jitterPct: 0,
      aiOnly: false,
    );

    testWidgets('editing multimedia muestra la identidad del tipo en el pill', (
      tester,
    ) async {
      await pumpHost(tester, editing: imgStep);

      expect(
        find.descendant(
          of: find.byKey(const Key('step_edit.type_pill')),
          matching: find.text('Imagen'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'editing multimedia SIN pickMediaRef muestra el chip read-only con el '
      'ref original y sin botón "Cambiar"',
      (tester) async {
        // Sin callback el media queda read-only (no hay vía para reemplazar).
        await pumpHost(tester, editing: imgStep);

        // El chip "Recurso seleccionado" está presente con una cola del ref.
        expect(
          find.byKey(const Key('step_edit.media_selected')),
          findsOneWidget,
        );
        expect(find.textContaining('orig.png'), findsOneWidget);
        // No hay selector "Seleccionar multimedia" (ya hay ref).
        expect(find.byKey(const Key('step_edit.media_picker')), findsNothing);
        // Sin callback no hay botón "Cambiar".
        expect(find.byKey(const Key('step_edit.media_change')), findsNothing);
      },
    );

    testWidgets(
      'editing multimedia con pickMediaRef cableado expone "Cambiar" — la '
      'edición de multimedia es interactiva',
      (tester) async {
        // Espeja producción: el call-site cablea pickMediaRef SIEMPRE, tanto
        // al crear como al editar. Con el callback presente, el chip de recurso
        // expone "Cambiar" para reabrir el picker y reemplazar el media. Sin
        // callback el chip queda read-only (test aparte). Este test le da
        // dientes al cableado interactivo de edición.
        await pumpHost(
          tester,
          editing: imgStep,
          pickMediaRef: (_, _) async => _asset('tenant/o/media/otro.png'),
        );

        expect(
          find.byKey(const Key('step_edit.media_selected')),
          findsOneWidget,
        );
        // El media ya está prefilled → el control es el chip con "Cambiar",
        // no el selector inicial.
        expect(find.byKey(const Key('step_edit.media_change')), findsOneWidget);
        expect(find.byKey(const Key('step_edit.media_picker')), findsNothing);
      },
    );

    testWidgets(
      'editing multimedia: "Cambiar" devuelve un nuevo ref BARE → submit '
      'dispatcha UpdateRequested(mediaRef) only-changed con ese ref exacto',
      (tester) async {
        // Re-pinea el linchpin a nivel de edición: lo que viaja como mediaRef
        // es exactamente el ref BARE que el picker devolvió (distinto del
        // original), y los demás campos quedan null (no cambiaron).
        const nuevoRef = 'tenant/org1/media/nuevo999.png';
        await pumpHost(
          tester,
          editing: imgStep,
          pickMediaRef: (_, _) async => _asset(nuevoRef),
        );

        await tester.tap(find.byKey(const Key('step_edit.media_change')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        verify(
          () => bloc.add(
            const FlowStepsUpdateRequested(
              stepId: 's-img',
              mediaRef: nuevoRef,
              // El media_filename del nuevo asset acompaña al ref reemplazado
              // (el _asset por default es 'file.png').
              metadataJson: '{"media_filename":"file.png"}',
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'editing multimedia: "Cambiar" devuelve el MISMO ref que el original → '
      'submit es no-op (mediaRef no cambió)',
      (tester) async {
        await pumpHost(
          tester,
          editing: imgStep,
          // Devuelve el ref idéntico al del step en edición.
          pickMediaRef: (_, _) async => _asset(imgStep.mediaRef),
        );

        await tester.tap(find.byKey(const Key('step_edit.media_change')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        verifyNever(() => bloc.add(any()));
      },
    );

    testWidgets(
      'editing multimedia: cambiar media Y caption → UpdateRequested con '
      'mediaRef y content ambos set',
      (tester) async {
        const nuevoRef = 'tenant/org1/media/nuevo999.png';
        await pumpHost(
          tester,
          editing: imgStep,
          pickMediaRef: (_, _) async => _asset(nuevoRef),
        );

        await tester.tap(find.byKey(const Key('step_edit.media_change')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'caption nuevo',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        verify(
          () => bloc.add(
            const FlowStepsUpdateRequested(
              stepId: 's-img',
              mediaRef: nuevoRef,
              content: 'caption nuevo',
              metadataJson: '{"media_filename":"file.png"}',
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'editing multimedia: cambiar caption dispatcha UpdateRequested(content) only-changed',
      (tester) async {
        await pumpHost(tester, editing: imgStep);

        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'caption nuevo',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        verify(
          () => bloc.add(
            const FlowStepsUpdateRequested(
              stepId: 's-img',
              content: 'caption nuevo',
            ),
          ),
        ).called(1);
      },
    );
  });

  group('StepEditSheet (Add mode · conditionalTime)', () {
    testWidgets(
      'crear con tipo Condicional muestra el form CT y oculta content/selector',
      (tester) async {
        await pumpHost(tester, createType: fdom.StepType.conditionalTime);
        await tester.pumpAndSettle();

        expect(find.text('Nuevo paso · Condicional'), findsOneWidget);
        // El form CT está presente.
        expect(find.byKey(const Key('ct_form.tz_dropdown')), findsOneWidget);
        // content y el selector de multimedia están ocultos.
        expect(find.byKey(const Key('step_edit.content')), findsNothing);
        expect(find.byKey(const Key('step_edit.media_picker')), findsNothing);
      },
    );

    testWidgets('sin elegir destinos el submit es no-op: el seed default ya no '
        'inventa ramas que truenan en runtime', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const FlowStepsLoaded(<fdom.Step>[_tHola, _tCerrados]));
      await pumpHost(tester, createType: fdom.StepType.conditionalTime);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();
      verifyNever(() => bloc.add(any()));
    });

    testWidgets(
      'elegir ambos destinos → AddRequested(conditionalTime, id-form, '
      'insertado ANTES de su destino más temprano)',
      (tester) async {
        when(
          () => bloc.state,
        ).thenReturn(const FlowStepsLoaded(<fdom.Step>[_tHola, _tCerrados]));
        await pumpHost(tester, createType: fdom.StepType.conditionalTime);
        await tester.pumpAndSettle();

        // match → "1. Hola" (order 0), else → "2. Cerrados" (order 1).
        await tester.tap(find.byKey(const Key('ct_form.on_match_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('1. Hola').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ct_form.on_else_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2. Cerrados').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        final captured = verify(() => bloc.add(captureAny())).captured;
        expect(captured, hasLength(1));
        final ev = captured.single as FlowStepsAddRequested;
        expect(ev.type, fdom.StepType.conditionalTime);
        expect(ev.metadataJson, isNotNull);
        expect(ev.metadataJson, contains('"on_match_step_id":"t-hola"'));
        expect(ev.metadataJson, contains('"on_else_step_id":"t-cerrados"'));
        expect(ev.metadataJson, isNot(contains('on_match_order')));
        // Inserción ante el destino más temprano (t-hola, order 0): el
        // backend desplaza y ambos destinos quedan después del CT.
        expect(ev.order, 0);
      },
    );

    testWidgets('con destinos elegidos, el caption vivo anuncia la posición de '
        'inserción antes de guardar', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const FlowStepsLoaded(<fdom.Step>[_tHola, _tCerrados]));
      await pumpHost(tester, createType: fdom.StepType.conditionalTime);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ct_form.insert_position')), findsNothing);

      await tester.tap(find.byKey(const Key('ct_form.on_match_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1. Hola').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ct_form.on_else_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2. Cerrados').last);
      await tester.pumpAndSettle();

      // El destino más temprano es t-hola (posición 1): el caption dice
      // exactamente dónde aparecerá el paso al guardar.
      expect(
        find.text('Este condicional se insertará antes del paso 1.'),
        findsOneWidget,
      );
    });

    testWidgets('MutationFailed con InvalidStepFailure en modo CT muestra copy '
        'específico de horario/destinos', (tester) async {
      when(() => bloc.state).thenReturn(
        const FlowStepsMutationFailed(<fdom.Step>[], FlowsInvalidStepFailure()),
      );
      await pumpHost(tester, createType: fdom.StepType.conditionalTime);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('step_edit.error.invalid_step.conditional')),
        findsOneWidget,
      );
      expect(
        find.text('Revisa horario o destinos del condicional.'),
        findsOneWidget,
      );
    });
  });

  group('StepEditSheet (END)', () {
    testWidgets(
      'crear tipo Fin muestra el resumen y NO ofrece opciones de envío '
      '(un paso que termina el flujo no envía nada)',
      (tester) async {
        await pumpHost(tester, createType: fdom.StepType.end);

        expect(find.text('Nuevo paso · Fin'), findsOneWidget);
        expect(find.byKey(const Key('step_edit.end_helper')), findsOneWidget);
        expect(find.byKey(const Key('step_edit.content')), findsNothing);
        expect(find.byKey(const Key('step_edit.send_options')), findsNothing);
      },
    );

    testWidgets(
      'submit END dispatcha AddRequested(end) sin campos y delayMs 0',
      (tester) async {
        await pumpHost(tester, createType: fdom.StepType.end);

        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        final captured = verify(() => bloc.add(captureAny())).captured;
        expect(captured, hasLength(1));
        final ev = captured.single as FlowStepsAddRequested;
        expect(ev.type, fdom.StepType.end);
        expect(ev.content, '');
        expect(ev.delayMs, 0);
        expect(ev.metadataJson, isNull);
      },
    );

    testWidgets(
      'editar un END con delay legacy 0 NO lo cura: Guardar sin tocar nada '
      'es no-op (END no envía al wire; un PATCH delayMs 1000 sería espurio)',
      (tester) async {
        const endStep = fdom.Step(
          id: 's-end',
          flowId: 'f1',
          type: fdom.StepType.end,
          order: 0,
          content: '',
          mediaRef: '',
          metadataJson: '{}',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        );
        when(
          () => bloc.state,
        ).thenReturn(const FlowStepsLoaded(<fdom.Step>[endStep]));
        await pumpHost(tester, editing: endStep);

        // Sin opciones de envío ni aviso de curación: END no tiene pacing.
        expect(find.byKey(const Key('step_edit.send_options')), findsNothing);
        expect(
          find.byKey(const Key('step_edit.legacy_delay_notice')),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        verifyNever(() => bloc.add(any()));
      },
    );
  });

  group('StepEditSheet (Edit mode · conditionalTime)', () {
    // Shape de PRODUCCIÓN: el listado del backend sintetiza los orders
    // legacy JUNTO a los ids. El no-op del submit debe sobrevivirlos (el
    // form re-emite id-form puro; comparar orders daría PATCH espurio).
    const ctStep = fdom.Step(
      id: 's-ct',
      flowId: 'f1',
      type: fdom.StepType.conditionalTime,
      order: 0,
      content: '',
      mediaRef: '',
      metadataJson:
          '{"tz":"UTC","windows":[{"days":[1,2],"from":"08:00",'
          '"to":"12:00"}],"on_match_step_id":"t-hola",'
          '"on_else_step_id":"t-cerrados",'
          '"on_match_order":1,"on_else_order":2}',
      // ≥1s: CONDITIONAL_TIME es no-LABEL, sujeto al piso de delay.
      delayMs: 1000,
      jitterPct: 0,
      aiOnly: false,
    );
    // El CT en order 0 con sus destinos después (1 y 2): los candidatos
    // del form al editar son SOLO los posteriores.
    const ctFlowSteps = <fdom.Step>[ctStep, _tHolaAt1, _tCerradosAt2];

    testWidgets(
      'edit CT hidrata el form con metadataJson del step (tz UTC visible)',
      (tester) async {
        when(() => bloc.state).thenReturn(const FlowStepsLoaded(ctFlowSteps));
        await pumpHost(tester, editing: ctStep);

        // El form CT está montado (no el content/media_url).
        expect(find.byKey(const Key('ct_form.tz_dropdown')), findsOneWidget);
        // tz dropdown muestra "UTC" como selección actual.
        expect(find.text('UTC'), findsWidgets);
        // Sin aviso de configuración recuperada: la metadata era legible.
        expect(
          find.byKey(const Key('ct_form.recovered_warning')),
          findsNothing,
        );
      },
    );

    testWidgets('edit CT sin cambios → submit es no-op', (tester) async {
      when(() => bloc.state).thenReturn(const FlowStepsLoaded(ctFlowSteps));
      await pumpHost(tester, editing: ctStep);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      verifyNever(() => bloc.add(any()));
    });

    testWidgets('edit CT con cambio (deselect día) → submit dispatcha '
        'UpdateRequested(metadataJson)', (tester) async {
      when(() => bloc.state).thenReturn(const FlowStepsLoaded(ctFlowSteps));
      await pumpHost(tester, editing: ctStep);
      await tester.pumpAndSettle();

      // El step original tiene days [1,2] (Lun+Mar). uiIndex 0=Lun.
      // Destildo Lunes — quedan solo Martes (wireDay 2).
      await tester.tap(find.byKey(const Key('ct_form.window.0.day.0')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      final captured = verify(() => bloc.add(captureAny())).captured;
      expect(captured, hasLength(1));
      final ev = captured.single as FlowStepsUpdateRequested;
      expect(ev.stepId, 's-ct');
      expect(ev.metadataJson, isNotNull);
      // Después del cambio, days = [2] solamente.
      expect(ev.metadataJson, contains('"days":[2]'));
      // Otros campos no van al PATCH.
      expect(ev.content, isNull);
      expect(ev.delayMs, isNull);
    });
  });

  group('StepEditSheet (LABEL)', () {
    testWidgets('crear tipo LABEL muestra el form (picker + acción) y oculta '
        'content/retraso; el modo vive en "Opciones de ejecución"', (
      tester,
    ) async {
      await pumpHost(tester, createType: fdom.StepType.label);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('step_edit.label_form')), findsOneWidget);
      expect(
        find.byKey(const Key('step_edit.label_action.add')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('step_edit.label_action.remove')),
        findsOneWidget,
      );
      // LABEL no envía al wire: sin campo de content ni pacing, pero el
      // modo de ejecución sí aplica y vive en su propio disclosure.
      expect(find.byKey(const Key('step_edit.content')), findsNothing);
      expect(find.text('Opciones de ejecución'), findsOneWidget);

      await openSendOptions(tester);
      expect(find.byKey(const Key('step_edit.delay.value')), findsNothing);
      expect(find.byKey(const Key('step_edit.jitter')), findsNothing);
      expect(find.byKey(const Key('step_edit.mode.always')), findsOneWidget);
    });

    testWidgets('submit LABEL sin elegir etiqueta es no-op', (tester) async {
      await pumpHost(tester, createType: fdom.StepType.label);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('elegir etiqueta (ADD por default) → submit dispatcha '
        'AddRequested(label, metadata {label_id, action:ADD})', (tester) async {
      await pumpHost(tester, createType: fdom.StepType.label);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('step_edit.label_picker.option.vip')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      final captured = verify(() => bloc.add(captureAny())).captured;
      expect(captured, hasLength(1));
      final ev = captured.single as FlowStepsAddRequested;
      expect(ev.type, fdom.StepType.label);
      expect(ev.content, '');
      expect(ev.mediaRef, '');
      expect(ev.metadataJson, isNotNull);
      final meta = jsonDecode(ev.metadataJson!) as Map<String, dynamic>;
      expect(meta['label_id'], 'vip');
      expect(meta['action'], 'ADD');
    });

    testWidgets('nuevo paso LABEL manda delayMs 0 (exento del piso)', (
      tester,
    ) async {
      await pumpHost(tester, createType: fdom.StepType.label);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('step_edit.label_picker.option.vip')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      final captured = verify(() => bloc.add(captureAny())).captured;
      final ev = captured.single as FlowStepsAddRequested;
      // LABEL no envía al wire: el piso de 1s no aplica, su delay queda en 0.
      expect(ev.delayMs, 0);
    });

    testWidgets('elegir acción "Quitar etiqueta" → metadata action:REMOVE', (
      tester,
    ) async {
      await pumpHost(tester, createType: fdom.StepType.label);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('step_edit.label_picker.option.vip')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('step_edit.label_action.remove')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      final captured = verify(() => bloc.add(captureAny())).captured;
      final ev = captured.single as FlowStepsAddRequested;
      final meta = jsonDecode(ev.metadataJson!) as Map<String, dynamic>;
      expect(meta['action'], 'REMOVE');
    });

    testWidgets(
      'edit LABEL: preselecciona etiqueta+acción del metadata; sin cambios '
      'es no-op',
      (tester) async {
        const editing = fdom.Step(
          id: 's-lbl',
          flowId: 'f1',
          type: fdom.StepType.label,
          order: 0,
          content: '',
          mediaRef: '',
          metadataJson: '{"label_id":"vip","action":"REMOVE"}',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        );
        await pumpHost(tester, editing: editing);
        await tester.pumpAndSettle();

        // El chip REMOVE arranca seleccionado (hidratado del metadata).
        final removeChip = tester.widget<AppChoiceChip>(
          find.byKey(const Key('step_edit.label_action.remove')),
        );
        expect(removeChip.selected, isTrue);

        // Sin cambios → submit no-op (only-changed del metadata).
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();
        verifyNever(() => bloc.add(any()));
      },
    );
  });

  group('showStepEditSheet', () {
    testWidgets('abre el modal sobre surface1 con blocs y catálogo cableados', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<FlowStepsBloc>.value(value: bloc),
            ],
            child: RepositoryProvider<LabelsRepository>.value(
              value: _FakeLabelsRepository(),
              child: Scaffold(
                body: Builder(
                  builder: (ctx) => Center(
                    child: ElevatedButton(
                      onPressed: () => showStepEditSheet(
                        ctx,
                        createType: fdom.StepType.text,
                      ),
                      child: const Text('open'),
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

      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, AppTokens.surface1);
      expect(find.byKey(const Key('step_edit.submit')), findsOneWidget);
    });

    testWidgets(
      'el sheet cierra en cuanto la mutación PERSISTIÓ (Refreshing), aunque '
      'el refetch posterior falle — no queda un sheet zombi con un Guardar '
      'que re-enviaría el cambio',
      (tester) async {
        final states = StreamController<FlowStepsState>();
        addTearDown(states.close);
        whenListen(
          bloc,
          states.stream,
          initialState: const FlowStepsLoaded(<fdom.Step>[]),
        );

        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppDesignTheme.dark(),
            home: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<FlowStepsBloc>.value(value: bloc),
              ],
              child: RepositoryProvider<LabelsRepository>.value(
                value: _FakeLabelsRepository(),
                child: Scaffold(
                  body: Builder(
                    builder: (ctx) => Center(
                      child: ElevatedButton(
                        onPressed: () => showStepEditSheet(
                          ctx,
                          createType: fdom.StepType.text,
                        ),
                        child: const Text('open'),
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

        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'Hola',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        states.add(const FlowStepsMutating(<fdom.Step>[]));
        await tester.pump();
        // La mutación ya persistió: el refetch corre con la lista visible…
        states.add(const FlowStepsRefreshing(<fdom.Step>[]));
        await tester.pumpAndSettle();
        // …y aunque el refetch falle, el sheet ya se fue: el cambio existe
        // en el backend y reintentar desde el sheet lo duplicaría.
        states.add(
          const FlowStepsRefreshFailed(<fdom.Step>[], FlowsServerFailure()),
        );
        await tester.pump();

        expect(find.byKey(const Key('step_edit.content')), findsNothing);
        expect(find.byKey(const Key('step_edit.submit')), findsNothing);
      },
    );

    testWidgets(
      'el pop post-submit ocurre UNA sola vez: el Loaded que llega durante '
      'la animación de salida del sheet no vuelve a popear (la página que '
      'abrió el sheet sobrevive)',
      (tester) async {
        final states = StreamController<FlowStepsState>();
        addTearDown(states.close);
        whenListen(
          bloc,
          states.stream,
          initialState: const FlowStepsLoaded(<fdom.Step>[]),
        );

        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppDesignTheme.dark(),
            home: Scaffold(
              body: Builder(
                builder: (baseCtx) => Center(
                  child: ElevatedButton(
                    key: const Key('probe.push'),
                    onPressed: () => Navigator.of(baseCtx).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MultiBlocProvider(
                          providers: <BlocProvider<dynamic>>[
                            BlocProvider<FlowStepsBloc>.value(value: bloc),
                          ],
                          child: RepositoryProvider<LabelsRepository>.value(
                            value: _FakeLabelsRepository(),
                            child: Scaffold(
                              body: Builder(
                                builder: (ctx) => Center(
                                  child: ElevatedButton(
                                    key: const Key('probe.open'),
                                    onPressed: () => showStepEditSheet(
                                      ctx,
                                      createType: fdom.StepType.text,
                                    ),
                                    child: const Text('open'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('push'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('probe.push')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('probe.open')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'Hola',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        states.add(const FlowStepsMutating(<fdom.Step>[]));
        await tester.pump();
        states.add(const FlowStepsRefreshing(<fdom.Step>[]));
        // Un frame: el pop del sheet arranca y su animación de salida corre.
        await tester.pump(const Duration(milliseconds: 32));
        // Refetch veloz: Loaded llega con el sheet todavía animando hacia
        // afuera — el listener sigue montado y NO debe volver a popear.
        states.add(const FlowStepsLoaded(<fdom.Step>[]));
        await tester.pump(const Duration(milliseconds: 32));
        await tester.pumpAndSettle();

        // El sheet se fue…
        expect(find.byKey(const Key('step_edit.submit')), findsNothing);
        // …pero la página que lo abrió DEBE seguir en pantalla.
        expect(find.byKey(const Key('probe.open')), findsOneWidget);
      },
    );
  });

  group('StepEditSheet · guard de descarte y pie Cancelar', () {
    // Abre el sheet por la vía de producción (showStepEditSheet), que es
    // donde vive el guard: scrim, drag y back pasan por la confirmación
    // cuando hay cambios sin guardar.
    Future<void> pumpGuardHost(
      WidgetTester tester, {
      fdom.Step? editing,
      fdom.StepType createType = fdom.StepType.text,
    }) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<FlowStepsBloc>.value(value: bloc),
            ],
            child: RepositoryProvider<LabelsRepository>.value(
              value: _FakeLabelsRepository(),
              child: Scaffold(
                body: Builder(
                  builder: (ctx) => Center(
                    child: ElevatedButton(
                      onPressed: () => showStepEditSheet(
                        ctx,
                        editing: editing,
                        createType: editing == null ? createType : null,
                      ),
                      child: const Text('open'),
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
    }

    Future<void> tapScrim(WidgetTester tester) async {
      await tester.tapAt(const Offset(400, 12));
      await tester.pumpAndSettle();
    }

    testWidgets('sin cambios: el scrim descarta directo, sin confirmación', (
      tester,
    ) async {
      await pumpGuardHost(tester);
      await tapScrim(tester);

      expect(find.text('¿Descartar los cambios?'), findsNothing);
      expect(find.byKey(const Key('step_edit.submit')), findsNothing);
    });

    testWidgets(
      'haber elegido el tipo en el selector NO cuenta como cambio: el sheet '
      'recién abierto descarta directo',
      (tester) async {
        await pumpGuardHost(tester, createType: fdom.StepType.image);
        await tapScrim(tester);

        expect(find.text('¿Descartar los cambios?'), findsNothing);
        expect(find.byKey(const Key('step_edit.submit')), findsNothing);
      },
    );

    testWidgets(
      'con cambios: el scrim pide confirmación y seguir editando conserva '
      'lo escrito',
      (tester) async {
        await pumpGuardHost(tester);
        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'Hola guard',
        );
        await tester.pump();

        await tapScrim(tester);
        expect(find.text('¿Descartar los cambios?'), findsOneWidget);

        await tester.tap(find.byKey(appSheetDiscardCancelKey));
        await tester.pumpAndSettle();
        // El sheet sigue montado con el texto intacto.
        expect(find.byKey(const Key('step_edit.submit')), findsOneWidget);
        expect(find.text('Hola guard'), findsOneWidget);
      },
    );

    testWidgets('con cambios: confirmar el descarte cierra el sheet', (
      tester,
    ) async {
      await pumpGuardHost(tester);
      await tester.enterText(
        find.byKey(const Key('step_edit.content')),
        'Hola guard',
      );
      await tester.pump();

      await tapScrim(tester);
      await tester.tap(find.byKey(appSheetDiscardConfirmKey));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('step_edit.submit')), findsNothing);
    });

    testWidgets(
      'el pie muestra Cancelar junto a Guardar; sin cambios Cancelar cierra '
      'directo',
      (tester) async {
        await pumpGuardHost(tester);
        expect(find.byKey(const Key('step_edit.cancel')), findsOneWidget);

        await tester.tap(find.byKey(const Key('step_edit.cancel')));
        await tester.pumpAndSettle();

        expect(find.text('¿Descartar los cambios?'), findsNothing);
        expect(find.byKey(const Key('step_edit.submit')), findsNothing);
      },
    );

    testWidgets('Cancelar con cambios pide confirmación (respeta el guard)', (
      tester,
    ) async {
      await pumpGuardHost(tester);
      await tester.enterText(
        find.byKey(const Key('step_edit.content')),
        'Trabajo a medias',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('step_edit.cancel')));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios?'), findsOneWidget);

      await tester.tap(find.byKey(appSheetDiscardCancelKey));
      await tester.pumpAndSettle();
      expect(find.text('Trabajo a medias'), findsOneWidget);
    });

    testWidgets('tocar el retraso ya cuenta como cambio', (tester) async {
      await pumpGuardHost(tester);
      await tester.tap(find.byKey(const Key('step_edit.send_options')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('step_edit.delay.slider')),
      );
      await tester.drag(
        find.byKey(const Key('step_edit.delay.slider')),
        const Offset(2000, 0),
      );
      await tester.pump();

      await tapScrim(tester);
      expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    });

    testWidgets(
      'Guardar no pide confirmación: el sheet cierra al persistir la mutación',
      (tester) async {
        final states = StreamController<FlowStepsState>();
        addTearDown(states.close);
        whenListen(
          bloc,
          states.stream,
          initialState: const FlowStepsLoaded(<fdom.Step>[]),
        );
        await pumpGuardHost(tester);

        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'Hola',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        states.add(const FlowStepsMutating(<fdom.Step>[]));
        await tester.pump();
        states.add(const FlowStepsRefreshing(<fdom.Step>[]));
        await tester.pumpAndSettle();

        expect(find.text('¿Descartar los cambios?'), findsNothing);
        expect(find.byKey(const Key('step_edit.submit')), findsNothing);
      },
    );

    testWidgets(
      'editar sin tocar nada: el scrim descarta directo (el diff no marca '
      'cambios)',
      (tester) async {
        when(
          () => bloc.state,
        ).thenReturn(const FlowStepsLoaded(<fdom.Step>[editingStep]));
        await pumpGuardHost(tester, editing: editingStep);

        await tapScrim(tester);

        expect(find.text('¿Descartar los cambios?'), findsNothing);
        expect(find.byKey(const Key('step_edit.submit')), findsNothing);
      },
    );

    testWidgets(
      'editar un CT sin tocar nada: el re-emit inicial del form no cuenta '
      'como cambio (scrim directo)',
      (tester) async {
        const ctStep = fdom.Step(
          id: 's-ct',
          flowId: 'f1',
          type: fdom.StepType.conditionalTime,
          order: 0,
          content: '',
          mediaRef: '',
          metadataJson:
              '{"tz":"UTC","windows":[{"days":[1,2],"from":"08:00",'
              '"to":"12:00"}],"on_match_step_id":"t-hola",'
              '"on_else_step_id":"t-cerrados",'
              '"on_match_order":1,"on_else_order":2}',
          delayMs: 1000,
          jitterPct: 0,
          aiOnly: false,
        );
        when(() => bloc.state).thenReturn(
          const FlowStepsLoaded(<fdom.Step>[ctStep, _tHolaAt1, _tCerradosAt2]),
        );
        await pumpGuardHost(tester, editing: ctStep);
        await tester.pumpAndSettle();

        await tapScrim(tester);

        expect(find.text('¿Descartar los cambios?'), findsNothing);
        expect(find.byKey(const Key('step_edit.submit')), findsNothing);
      },
    );

    testWidgets(
      'el delay legacy curado al abrir (0→1s) NO cuenta como cambio del '
      'operador',
      (tester) async {
        const legacy = fdom.Step(
          id: 's-legacy',
          flowId: 'f1',
          type: fdom.StepType.text,
          order: 0,
          content: 'old',
          mediaRef: '',
          metadataJson: '{}',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        );
        when(
          () => bloc.state,
        ).thenReturn(const FlowStepsLoaded(<fdom.Step>[legacy]));
        await pumpGuardHost(tester, editing: legacy);

        await tapScrim(tester);

        expect(find.text('¿Descartar los cambios?'), findsNothing);
        expect(find.byKey(const Key('step_edit.submit')), findsNothing);
      },
    );

    testWidgets(
      'un condicional a medias (aún inválido) también protege el trabajo: '
      'tocar un día basta para pedir confirmación',
      (tester) async {
        when(
          () => bloc.state,
        ).thenReturn(const FlowStepsLoaded(<fdom.Step>[_tHola, _tCerrados]));
        await pumpGuardHost(tester, createType: fdom.StepType.conditionalTime);
        await tester.pumpAndSettle();

        // Sin destinos elegidos el form emite null (inválido), pero el día
        // alternado YA es trabajo del operador.
        await tester.tap(find.byKey(const Key('ct_form.window.0.day.0')));
        await tester.pump();

        await tapScrim(tester);
        expect(find.text('¿Descartar los cambios?'), findsOneWidget);
      },
    );

    testWidgets(
      'romper la config de un CT en edición (el form vuelve a emitir null) '
      'sigue protegido por el guard',
      (tester) async {
        const ctStep = fdom.Step(
          id: 's-ct',
          flowId: 'f1',
          type: fdom.StepType.conditionalTime,
          order: 0,
          content: '',
          mediaRef: '',
          metadataJson:
              '{"tz":"UTC","windows":[{"days":[1,2],"from":"08:00",'
              '"to":"12:00"}],"on_match_step_id":"t-hola",'
              '"on_else_step_id":"t-cerrados"}',
          delayMs: 1000,
          jitterPct: 0,
          aiOnly: false,
        );
        when(() => bloc.state).thenReturn(
          const FlowStepsLoaded(<fdom.Step>[ctStep, _tHolaAt1, _tCerradosAt2]),
        );
        await pumpGuardHost(tester, editing: ctStep);
        await tester.pumpAndSettle();

        // Destildar TODOS los días deja la ventana inválida: el form emite
        // null y el diff only-changed ya no ve la metadata — pero el estado
        // a medias es distinto del original y descartar lo perdería.
        await tester.tap(find.byKey(const Key('ct_form.window.0.day.0')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('ct_form.window.0.day.1')));
        await tester.pump();

        await tapScrim(tester);
        expect(find.text('¿Descartar los cambios?'), findsOneWidget);
      },
    );

    testWidgets(
      'tras un fallo de mutación los cambios siguen protegidos por el guard',
      (tester) async {
        final states = StreamController<FlowStepsState>();
        addTearDown(states.close);
        whenListen(
          bloc,
          states.stream,
          initialState: const FlowStepsLoaded(<fdom.Step>[]),
        );
        await pumpGuardHost(tester);

        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'Hola',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        states.add(const FlowStepsMutating(<fdom.Step>[]));
        await tester.pump();
        // La mutación murió: el intento no persistió y el trabajo sigue vivo.
        states.add(
          const FlowStepsMutationFailed(<fdom.Step>[], FlowsServerFailure()),
        );
        await tester.pump();

        await tapScrim(tester);
        expect(find.text('¿Descartar los cambios?'), findsOneWidget);
        expect(find.byKey(const Key('step_edit.submit')), findsOneWidget);
      },
    );
  });
}

/// Catálogo mínimo para el LabelsBloc que showStepEditSheet crea él mismo.
class _FakeLabelsRepository implements LabelsRepository {
  @override
  Future<List<Label>> listLabels() async => <Label>[_lbl()];

  @override
  Future<Label> createLabel({
    required String name,
    required String color,
    required String description,
  }) => throw UnimplementedError();

  @override
  Future<Label> updateLabel({
    required String id,
    required String name,
    required String color,
    required String description,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteLabel({required String id}) => throw UnimplementedError();
}
