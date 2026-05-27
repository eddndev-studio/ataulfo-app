import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/features/flows/domain/entities/step.dart' as fdom;
import 'package:agentic/features/flows/domain/failures/flows_failure.dart';
import 'package:agentic/features/flows/presentation/bloc/flow_steps_bloc.dart';
import 'package:agentic/features/flows/presentation/widgets/step_edit_sheet.dart';
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

  // Surface 800x600 (default de flutter_test) deja el submit fuera del
  // viewport tras añadir el picker de tipo en F6. `pumpHost` agranda el
  // viewport para que tap(submit) conecte y restaura al final del test.
  Future<void> pumpHost(WidgetTester tester, {fdom.Step? editing}) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<FlowStepsBloc>.value(
          value: bloc,
          child: Scaffold(
            body: SafeArea(child: StepEditSheet(editing: editing)),
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
      'renderiza picker con 7 chips (text + 6 multimedia); default TEXT',
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
        ]) {
          expect(
            find.byKey(Key('step_edit.type.$id')),
            findsOneWidget,
            reason: 'falta chip step_edit.type.$id',
          );
        }

        final textChip = tester.widget<ChoiceChip>(
          find.byKey(const Key('step_edit.type.text')),
        );
        expect(textChip.selected, isTrue);
        final imageChip = tester.widget<ChoiceChip>(
          find.byKey(const Key('step_edit.type.image')),
        );
        expect(imageChip.selected, isFalse);
      },
    );

    testWidgets(
      'media_url aparece al elegir tipo multimedia y desaparece en TEXT',
      (tester) async {
        await pumpHost(tester);

        // TEXT por default → sin media_url
        expect(find.byKey(const Key('step_edit.media_url')), findsNothing);

        // Cambio a IMAGE → media_url visible
        await tester.tap(find.byKey(const Key('step_edit.type.image')));
        await tester.pump();
        expect(find.byKey(const Key('step_edit.media_url')), findsOneWidget);

        // Vuelvo a TEXT → media_url se oculta
        await tester.tap(find.byKey(const Key('step_edit.type.text')));
        await tester.pump();
        expect(find.byKey(const Key('step_edit.media_url')), findsNothing);
      },
    );

    testWidgets(
      'submit multimedia con media_url y caption vacío dispatcha AddRequested',
      (tester) async {
        await pumpHost(tester);

        await tester.tap(find.byKey(const Key('step_edit.type.image')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('step_edit.media_url')),
          'http://x.png',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        verify(
          () => bloc.add(
            const FlowStepsAddRequested(
              type: fdom.StepType.image,
              mediaRef: 'http://x.png',
              content: '',
              delayMs: 0,
              jitterPct: 0,
              aiOnly: false,
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'submit multimedia sin media_url es no-op (gate del trim)',
      (tester) async {
        await pumpHost(tester);

        await tester.tap(find.byKey(const Key('step_edit.type.image')));
        await tester.pump();
        // Sin enterText en media_url
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

    testWidgets(
      'editing multimedia oculta el picker (type inmutable)',
      (tester) async {
        await pumpHost(tester, editing: imgStep);

        for (final id in const <String>[
          'text',
          'image',
          'video',
          'document',
          'audio',
          'ptt',
          'sticker',
        ]) {
          expect(
            find.byKey(Key('step_edit.type.$id')),
            findsNothing,
            reason: 'chip step_edit.type.$id no debería aparecer en edit',
          );
        }
      },
    );

    testWidgets(
      'editing multimedia muestra media_url con el valor original (read-only)',
      (tester) async {
        await pumpHost(tester, editing: imgStep);

        expect(find.byKey(const Key('step_edit.media_url')), findsOneWidget);
        expect(find.text('https://x/orig.png'), findsOneWidget);
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
}
