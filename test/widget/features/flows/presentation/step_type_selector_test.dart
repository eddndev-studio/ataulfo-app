import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/flows/domain/entities/step.dart' as fdom;
import 'package:ataulfo/features/flows/presentation/widgets/step_type_label.dart';
import 'package:ataulfo/features/flows/presentation/widgets/step_type_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El primer tiempo del creador de pasos: un selector rico agrupado
/// (Mensajes / Lógica / Acciones) que reemplaza al muro de chips idénticos.
/// Cada opción lleva glifo + caption de una línea; el operador entiende QUÉ
/// envía cada tipo antes de elegirlo.
void main() {
  Future<void> pumpHost(
    WidgetTester tester, {
    required ValueChanged<fdom.StepType?> onResult,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                key: const Key('probe.open'),
                onPressed: () async {
                  final t = await showStepTypeSelector(ctx);
                  onResult(t);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('probe.open')));
    await tester.pumpAndSettle();
  }

  group('showStepTypeSelector', () {
    testWidgets('renderiza las tres secciones con los 10 tipos elegibles', (
      tester,
    ) async {
      await pumpHost(tester, onResult: (_) {});

      expect(find.text('Tipo de paso'), findsOneWidget);
      expect(find.text('Mensajes'), findsOneWidget);
      expect(find.text('Lógica'), findsOneWidget);
      expect(find.text('Acciones'), findsOneWidget);

      for (final id in const <String>[
        'text',
        'image',
        'video',
        'document',
        'audio',
        'ptt',
        'sticker',
        'conditionalTime',
        'label',
        'end',
      ]) {
        expect(
          find.byKey(Key('step_edit.type.$id')),
          findsOneWidget,
          reason: 'falta la opción step_edit.type.$id',
        );
      }
    });

    testWidgets('la nota de voz se llama por su nombre — la jerga PTT muere', (
      tester,
    ) async {
      await pumpHost(tester, onResult: (_) {});

      expect(find.text('Nota de voz'), findsOneWidget);
      expect(find.text('PTT'), findsNothing);
    });

    testWidgets('cada opción explica qué hace con una caption de una línea', (
      tester,
    ) async {
      await pumpHost(tester, onResult: (_) {});

      // La semántica de la lógica se lee ANTES de elegir, no después.
      expect(find.text('Condición de horario'), findsOneWidget);
      expect(find.text('Ramifica según día y hora'), findsOneWidget);
      expect(find.text('Fin de rama'), findsOneWidget);
      expect(find.text('Termina el flujo aquí'), findsOneWidget);
      expect(
        find.text('Aplica una etiqueta al chat, sin enviar nada'),
        findsOneWidget,
      );
    });

    testWidgets('elegir una opción resuelve con su StepType y cierra la hoja', (
      tester,
    ) async {
      fdom.StepType? result = fdom.StepType.unsupported;
      await pumpHost(tester, onResult: (t) => result = t);

      await tester.tap(find.byKey(const Key('step_edit.type.image')));
      await tester.pumpAndSettle();

      expect(result, fdom.StepType.image);
      expect(find.text('Tipo de paso'), findsNothing);
    });

    testWidgets('descartar la hoja resuelve null (cancelar no elige nada)', (
      tester,
    ) async {
      fdom.StepType? result = fdom.StepType.unsupported;
      await pumpHost(tester, onResult: (t) => result = t);

      await tester.tapAt(const Offset(400, 12));
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(find.text('Tipo de paso'), findsNothing);
    });
  });

  group('stepTypeLabel', () {
    test('PTT se humaniza como "Nota de voz" en todo el editor', () {
      expect(stepTypeLabel(fdom.StepType.ptt), 'Nota de voz');
    });
  });
}
