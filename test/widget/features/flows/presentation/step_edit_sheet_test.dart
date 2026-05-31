import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_choice_chip.dart';
import 'package:ataulfo/features/flows/domain/entities/step.dart' as fdom;
import 'package:ataulfo/features/flows/domain/failures/flows_failure.dart';
import 'package:ataulfo/features/flows/presentation/bloc/flow_steps_bloc.dart';
import 'package:ataulfo/features/flows/presentation/widgets/step_edit_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<FlowStepsEvent, FlowStepsState>
    implements FlowStepsBloc {}

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

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.state).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));
  });

  // El sheet con todos los controles + form CONDITIONAL_TIME (chip
  // picker + ventanas con time pickers + dropdowns) supera el viewport
  // default de flutter_test (800x600). `pumpHost` agranda y restaura.
  //
  // [pickMediaRef] cablea el selector de multimedia. Cuando es null el
  // selector es read-only (no abre nada): así el sheet sigue testeable
  // aislado. Los tests que ejercen la selección pasan un fake que
  // devuelve un `ref` BARE conocido.
  Future<void> pumpHost(
    WidgetTester tester, {
    fdom.Step? editing,
    MediaRefPicker? pickMediaRef,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<FlowStepsBloc>.value(
          value: bloc,
          child: Scaffold(
            body: SafeArea(
              child: StepEditSheet(
                editing: editing,
                pickMediaRef: pickMediaRef,
              ),
            ),
          ),
        ),
      ),
    );
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
    testWidgets('renderiza título "Nuevo paso", campo content y sliders', (
      tester,
    ) async {
      await pumpHost(tester);

      expect(find.text('Nuevo paso'), findsOneWidget);
      expect(find.byKey(const Key('step_edit.content')), findsOneWidget);
      expect(find.byKey(const Key('step_edit.delay_slider')), findsOneWidget);
      expect(find.byKey(const Key('step_edit.jitter_slider')), findsOneWidget);
      expect(find.byKey(const Key('step_edit.ai_only_switch')), findsOneWidget);
      expect(find.byKey(const Key('step_edit.submit')), findsOneWidget);
    });

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
              delayMs: 0,
              jitterPct: 0,
              aiOnly: false,
            ),
          ),
        ).called(1);
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
      'renderiza picker con 8 chips (text + 6 multimedia + conditionalTime); '
      'default TEXT',
      (tester) async {
        await pumpHost(tester);

        for (final id in const <String>[
          'text',
          'image',
          'video',
          'document',
          'audio',
          'ptt',
          'sticker',
          'conditionalTime',
        ]) {
          expect(
            find.byKey(Key('step_edit.type.$id')),
            findsOneWidget,
            reason: 'falta chip step_edit.type.$id',
          );
        }

        final textChip = tester.widget<AppChoiceChip>(
          find.byKey(const Key('step_edit.type.text')),
        );
        expect(textChip.selected, isTrue);
        final imageChip = tester.widget<AppChoiceChip>(
          find.byKey(const Key('step_edit.type.image')),
        );
        expect(imageChip.selected, isFalse);
        final ctChip = tester.widget<AppChoiceChip>(
          find.byKey(const Key('step_edit.type.conditionalTime')),
        );
        expect(ctChip.selected, isFalse);
      },
    );

    testWidgets('el selector de multimedia aparece al elegir tipo multimedia y '
        'desaparece en TEXT', (tester) async {
      await pumpHost(tester);

      // TEXT por default → sin selector de multimedia.
      expect(find.byKey(const Key('step_edit.media_picker')), findsNothing);

      // Cambio a IMAGE → el selector "Seleccionar multimedia" aparece.
      await tester.tap(find.byKey(const Key('step_edit.type.image')));
      await tester.pump();
      expect(find.byKey(const Key('step_edit.media_picker')), findsOneWidget);

      // Vuelvo a TEXT → el selector se oculta.
      await tester.tap(find.byKey(const Key('step_edit.type.text')));
      await tester.pump();
      expect(find.byKey(const Key('step_edit.media_picker')), findsNothing);
    });

    testWidgets(
      'elegir un asset vía el picker y submit dispatcha AddRequested con el '
      'ref BARE devuelto (caption vacío)',
      (tester) async {
        // El picker fake devuelve el `ref` BARE canónico. El evento
        // despachado DEBE llevar exactamente ese ref — re-pinea el
        // linchpin a nivel del sheet: lo que se persiste es el ref BARE.
        const bareRef = 'tenant/org1/media/abc123.png';
        await pumpHost(tester, pickMediaRef: (_) async => bareRef);

        await tester.tap(find.byKey(const Key('step_edit.type.image')));
        await tester.pump();
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
              delayMs: 0,
              jitterPct: 0,
              aiOnly: false,
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('submit multimedia sin selección es no-op (gate del trim)', (
      tester,
    ) async {
      await pumpHost(tester, pickMediaRef: (_) async => 'tenant/o/media/x.png');

      await tester.tap(find.byKey(const Key('step_edit.type.image')));
      await tester.pump();
      // Sin tocar el picker → _mediaCtrl sigue vacío.
      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      verifyNever(() => bloc.add(any()));
    });

    testWidgets(
      'cancelar el picker (devuelve null) no cambia nada; submit sigue no-op',
      (tester) async {
        await pumpHost(tester, pickMediaRef: (_) async => null);

        await tester.tap(find.byKey(const Key('step_edit.type.image')));
        await tester.pump();
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

    testWidgets('renderiza título "Editar paso" y prefilling del content', (
      tester,
    ) async {
      await pumpHost(tester, editing: editingStep);

      expect(find.text('Editar paso'), findsOneWidget);
      // El TextField está prefilled con el content del editing.
      final tf = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('step_edit.content')),
          matching: find.byType(TextField),
        ),
      );
      expect(tf.controller?.text, 'Hola original');
    });

    testWidgets('edit con cambios dispatcha UpdateRequested con only-changed', (
      tester,
    ) async {
      await pumpHost(tester, editing: editingStep);
      // Cambia solo el content; los sliders/switch quedan iguales.
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

        // El dialog de confirmación aparece.
        expect(
          find.byKey(const Key('step_edit.delete_confirm')),
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
      delayMs: 0,
      jitterPct: 0,
      aiOnly: false,
    );

    testWidgets('editing multimedia oculta el picker (type inmutable)', (
      tester,
    ) async {
      await pumpHost(tester, editing: imgStep);

      for (final id in const <String>[
        'text',
        'image',
        'video',
        'document',
        'audio',
        'ptt',
        'sticker',
        'conditionalTime',
      ]) {
        expect(
          find.byKey(Key('step_edit.type.$id')),
          findsNothing,
          reason: 'chip step_edit.type.$id no debería aparecer en edit',
        );
      }
    });

    testWidgets(
      'editing multimedia muestra el chip read-only con el ref original y '
      'sin botón "Cambiar"',
      (tester) async {
        await pumpHost(tester, editing: imgStep);

        // El chip "Recurso seleccionado" está presente con una cola del ref.
        expect(
          find.byKey(const Key('step_edit.media_selected')),
          findsOneWidget,
        );
        expect(find.textContaining('orig.png'), findsOneWidget);
        // No hay selector "Seleccionar multimedia" (ya hay ref).
        expect(find.byKey(const Key('step_edit.media_picker')), findsNothing);
        // En edición el media es read-only: no hay botón "Cambiar".
        expect(find.byKey(const Key('step_edit.media_change')), findsNothing);
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
      'pick chip Condicional muestra el form CT y oculta content/selector',
      (tester) async {
        await pumpHost(tester);

        await tester.tap(
          find.byKey(const Key('step_edit.type.conditionalTime')),
        );
        await tester.pumpAndSettle();

        // El form CT está presente.
        expect(find.byKey(const Key('ct_form.tz_dropdown')), findsOneWidget);
        // content y el selector de multimedia están ocultos.
        expect(find.byKey(const Key('step_edit.content')), findsNothing);
        expect(find.byKey(const Key('step_edit.media_picker')), findsNothing);
      },
    );

    testWidgets(
      'submit con seed default dispatcha AddRequested(conditionalTime, '
      'metadataJson)',
      (tester) async {
        await pumpHost(tester);

        await tester.tap(
          find.byKey(const Key('step_edit.type.conditionalTime')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        // Captura el evento despachado y verifica el shape.
        final captured = verify(() => bloc.add(captureAny())).captured;
        expect(captured, hasLength(1));
        final ev = captured.single as FlowStepsAddRequested;
        expect(ev.type, fdom.StepType.conditionalTime);
        expect(ev.content, '');
        expect(ev.mediaRef, '');
        expect(ev.metadataJson, isNotNull);
        // Seed default: L-V 09-18 + tz México + onMatch 0/onElse 1.
        expect(ev.metadataJson, contains('America/Mexico_City'));
        expect(ev.metadataJson, contains('09:00'));
        expect(ev.metadataJson, contains('18:00'));
      },
    );

    testWidgets('MutationFailed con InvalidStepFailure en modo CT muestra copy '
        'específico de horario/destinos', (tester) async {
      when(() => bloc.state).thenReturn(
        const FlowStepsMutationFailed(<fdom.Step>[], FlowsInvalidStepFailure()),
      );
      await pumpHost(tester);
      await tester.tap(find.byKey(const Key('step_edit.type.conditionalTime')));
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

  group('StepEditSheet (Edit mode · conditionalTime)', () {
    const ctStep = fdom.Step(
      id: 's-ct',
      flowId: 'f1',
      type: fdom.StepType.conditionalTime,
      order: 2,
      content: '',
      mediaRef: '',
      metadataJson:
          '{"tz":"UTC","windows":[{"days":[1,2],"from":"08:00",'
          '"to":"12:00"}],"on_match_order":0,"on_else_order":1}',
      delayMs: 0,
      jitterPct: 0,
      aiOnly: false,
    );

    testWidgets(
      'edit CT hidrata el form con metadataJson del step (tz UTC visible)',
      (tester) async {
        when(
          () => bloc.state,
        ).thenReturn(const FlowStepsLoaded(<fdom.Step>[ctStep]));
        await pumpHost(tester, editing: ctStep);

        // El form CT está montado (no el content/media_url).
        expect(find.byKey(const Key('ct_form.tz_dropdown')), findsOneWidget);
        // tz dropdown muestra "UTC" como selección actual.
        expect(find.text('UTC'), findsWidgets);
      },
    );

    testWidgets('edit CT sin cambios → submit es no-op', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const FlowStepsLoaded(<fdom.Step>[ctStep]));
      await pumpHost(tester, editing: ctStep);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      verifyNever(() => bloc.add(any()));
    });

    testWidgets('edit CT con cambio (deselect día) → submit dispatcha '
        'UpdateRequested(metadataJson)', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const FlowStepsLoaded(<fdom.Step>[ctStep]));
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
}
