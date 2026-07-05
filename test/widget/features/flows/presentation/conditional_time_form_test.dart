import 'dart:convert';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_choice_chip.dart';
import 'package:ataulfo/core/design/widgets/app_select_field.dart';
import 'package:ataulfo/features/flows/domain/entities/conditional_time_metadata.dart';
import 'package:ataulfo/features/flows/presentation/widgets/conditional_time_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper para montar el form aislado y capturar el último `onChanged`.
class CaptureSink {
  String? last;
  int calls = 0;
}

const _defaultTargets = <CtTargetOption>[
  CtTargetOption(id: 'sA', order: 0, label: 'Hola, ¿en qué te ayudo?'),
  CtTargetOption(id: 'sB', order: 1, label: 'Imagen'),
  CtTargetOption(id: 'sC', order: 2, label: 'Estamos cerrados'),
  CtTargetOption(id: 'sD', order: 3, label: 'Fin'),
];

Future<CaptureSink> pumpForm(
  WidgetTester tester, {
  ConditionalTimeMetadata? initial,
  List<CtTargetOption> targets = _defaultTargets,
  bool enabled = true,
  bool showRecoveredWarning = false,
}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final capture = CaptureSink();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ConditionalTimeForm(
            initial: initial,
            targets: targets,
            enabled: enabled,
            showRecoveredWarning: showRecoveredWarning,
            onChanged: (json) {
              capture.last = json;
              capture.calls += 1;
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return capture;
}

/// Selecciona destinos en ambos dropdowns (match → sC, else → sA).
Future<void> selectTargets(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('ct_form.on_match_dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('3. Estamos cerrados').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('ct_form.on_else_dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('1. Hola, ¿en qué te ayudo?').last);
  await tester.pumpAndSettle();
}

void main() {
  group('ConditionalTimeForm (kit)', () {
    testWidgets('tz y destinos son AppSelectField del design system', (
      tester,
    ) async {
      await pumpForm(tester);

      // Los selects no reinventan el idioma (DropdownButtonFormField con
      // decoración Material): usan el AppSelectField del kit.
      expect(
        tester.widget(find.byKey(const Key('ct_form.tz_dropdown'))),
        isA<AppSelectField<String>>(),
      );
      expect(
        tester.widget(find.byKey(const Key('ct_form.on_match_dropdown'))),
        isA<AppSelectField<String>>(),
      );
      expect(
        tester.widget(find.byKey(const Key('ct_form.on_else_dropdown'))),
        isA<AppSelectField<String>>(),
      );
    });
  });

  group('ConditionalTimeForm (create)', () {
    testWidgets(
      'mount inicial SIN destinos → onChanged(null): elegir las ramas es '
      'decisión explícita, no un default que truena en runtime',
      (tester) async {
        final cap = await pumpForm(tester);
        expect(cap.calls, greaterThan(0));
        expect(cap.last, isNull);
      },
    );

    testWidgets(
      'elegir ambos destinos → onChanged emite id-form con defaults de '
      'horario (L-V 09:00-18:00, tz America/Mexico_City)',
      (tester) async {
        final cap = await pumpForm(tester);
        await selectTargets(tester);

        expect(cap.last, isNotNull);
        final md = ConditionalTimeMetadata.fromJsonString(cap.last!);
        expect(md.tz, 'America/Mexico_City');
        expect(md.windows, hasLength(1));
        expect(md.windows.first.days, <int>[1, 2, 3, 4, 5]);
        expect(md.windows.first.from, '09:00');
        expect(md.windows.first.to, '18:00');
        expect(md.onMatchStepId, 'sC');
        expect(md.onElseStepId, 'sA');
        // El wire nuevo es id-form puro: sin claves posicionales.
        final raw = jsonDecode(cap.last!) as Map<String, dynamic>;
        expect(raw.containsKey('on_match_order'), isFalse);
      },
    );

    testWidgets(
      'usa componentes del design system (AppChoiceChip días, AppButton '
      'horas y agregar ventana)',
      (tester) async {
        await pumpForm(tester);

        expect(
          tester.widget(find.byKey(const Key('ct_form.window.0.day.0'))),
          isA<AppChoiceChip>(),
        );
        expect(
          tester.widget(find.byKey(const Key('ct_form.window.0.from'))),
          isA<AppButton>(),
        );
        expect(
          tester.widget(find.byKey(const Key('ct_form.window.0.to'))),
          isA<AppButton>(),
        );
        expect(
          tester.widget(find.byKey(const Key('ct_form.add_window'))),
          isA<AppButton>(),
        );
      },
    );

    testWidgets(
      'destildar TODOS los días de la única ventana → onChanged(null)',
      (tester) async {
        final cap = await pumpForm(tester);
        await selectTargets(tester);
        expect(cap.last, isNotNull);

        for (final uiIdx in <int>[0, 1, 2, 3, 4]) {
          await tester.tap(find.byKey(Key('ct_form.window.0.day.$uiIdx')));
          await tester.pump();
        }
        expect(cap.last, isNull, reason: 'sin días, metadataJson inválido');
      },
    );

    testWidgets('agregar Sábado (uiIndex 5) → metadataJson con wireDay 6', (
      tester,
    ) async {
      final cap = await pumpForm(tester);
      await selectTargets(tester);
      await tester.tap(find.byKey(const Key('ct_form.window.0.day.5')));
      await tester.pump();

      expect(cap.last, isNotNull);
      final md = ConditionalTimeMetadata.fromJsonString(cap.last!);
      expect(md.windows.first.days, <int>[1, 2, 3, 4, 5, 6]);
    });

    testWidgets(
      'agregar Domingo (uiIndex 6) → wireDay 0 al inicio de la lista ordenada',
      (tester) async {
        final cap = await pumpForm(tester);
        await selectTargets(tester);
        await tester.tap(find.byKey(const Key('ct_form.window.0.day.6')));
        await tester.pump();

        expect(cap.last, isNotNull);
        final md = ConditionalTimeMetadata.fromJsonString(cap.last!);
        expect(md.windows.first.days, <int>[0, 1, 2, 3, 4, 5]);
      },
    );
  });

  group('ConditionalTimeForm (initial pre-cargado)', () {
    testWidgets(
      'monta con initial id-form → onChanged emite metadataJson equivalente',
      (tester) async {
        const initial = ConditionalTimeMetadata(
          tz: 'UTC',
          windows: <TimeWindow>[
            TimeWindow(days: <int>[0, 6], from: '10:00', to: '12:00'),
          ],
          onMatchStepId: 'sC',
          onElseStepId: 'sA',
        );
        final cap = await pumpForm(tester, initial: initial);

        expect(cap.last, isNotNull);
        final md = ConditionalTimeMetadata.fromJsonString(cap.last!);
        expect(md.tz, 'UTC');
        expect(md.onMatchStepId, 'sC');
        expect(md.onElseStepId, 'sA');
        expect(md.windows.first.days, <int>[0, 6]);
        expect(md.windows.first.from, '10:00');
        expect(md.windows.first.to, '12:00');
      },
    );

    testWidgets(
      'destino del initial que ya no es candidato → queda sin selección y '
      'el form emite null hasta re-elegir',
      (tester) async {
        const initial = ConditionalTimeMetadata(
          tz: 'UTC',
          windows: <TimeWindow>[
            TimeWindow(days: <int>[1], from: '10:00', to: '12:00'),
          ],
          onMatchStepId: 'ghost',
          onElseStepId: 'sA',
        );
        final cap = await pumpForm(tester, initial: initial);
        expect(cap.last, isNull);
      },
    );

    testWidgets('cambio del dropdown TZ → onChanged emite con nuevo tz', (
      tester,
    ) async {
      final cap = await pumpForm(tester);
      await selectTargets(tester);
      final before = jsonDecode(cap.last!) as Map<String, dynamic>;
      expect(before['tz'], 'America/Mexico_City');

      await tester.tap(find.byKey(const Key('ct_form.tz_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UTC').last);
      await tester.pumpAndSettle();

      expect(cap.last, isNotNull);
      final after = jsonDecode(cap.last!) as Map<String, dynamic>;
      expect(after['tz'], 'UTC');
    });
  });

  group('ConditionalTimeForm (destinos)', () {
    testWidgets('las opciones muestran posición + contenido del paso destino', (
      tester,
    ) async {
      await pumpForm(tester);
      await tester.tap(find.byKey(const Key('ct_form.on_match_dropdown')));
      await tester.pumpAndSettle();
      expect(find.text('1. Hola, ¿en qué te ayudo?'), findsWidgets);
      expect(find.text('3. Estamos cerrados'), findsWidgets);
    });

    testWidgets('sin candidatos → guía al operador y el form emite null', (
      tester,
    ) async {
      final cap = await pumpForm(tester, targets: const <CtTargetOption>[]);
      expect(cap.last, isNull);
      expect(find.textContaining('Agrega primero los pasos'), findsWidgets);
    });

    testWidgets('aviso de configuración recuperada visible cuando aplica', (
      tester,
    ) async {
      await pumpForm(tester, showRecoveredWarning: true);
      expect(
        find.byKey(const Key('ct_form.recovered_warning')),
        findsOneWidget,
      );
    });
  });

  group('ConditionalTimeForm (multi-ventana)', () {
    testWidgets(
      'botón "Agregar ventana" añade ventana extra y onChanged la incluye',
      (tester) async {
        final cap = await pumpForm(tester);
        await selectTargets(tester);
        final initialCalls = cap.calls;

        await tester.tap(find.byKey(const Key('ct_form.add_window')));
        await tester.pump();

        expect(cap.calls, greaterThan(initialCalls));
        final md = ConditionalTimeMetadata.fromJsonString(cap.last!);
        expect(
          md.windows,
          hasLength(2),
          reason: 'la 2da ventana debe estar agregada',
        );
        expect(find.byKey(const Key('ct_form.window.1.day.0')), findsOneWidget);
      },
    );

    testWidgets('botón "Eliminar ventana" desaparece cuando queda una sola; '
        'con dos, elimina la segunda', (tester) async {
      final cap = await pumpForm(tester);
      await selectTargets(tester);
      expect(find.byKey(const Key('ct_form.window.0.remove')), findsNothing);

      await tester.tap(find.byKey(const Key('ct_form.add_window')));
      await tester.pump();
      expect(find.byKey(const Key('ct_form.window.0.remove')), findsOneWidget);
      expect(find.byKey(const Key('ct_form.window.1.remove')), findsOneWidget);

      await tester.tap(find.byKey(const Key('ct_form.window.1.remove')));
      await tester.pump();
      final md = ConditionalTimeMetadata.fromJsonString(cap.last!);
      expect(md.windows, hasLength(1));
    });
  });

  group('aviso inline de ventana inválida (barrido UX)', () {
    testWidgets('desde ≥ hasta muestra el motivo del bloqueo', (tester) async {
      await pumpForm(
        tester,
        initial: const ConditionalTimeMetadata(
          tz: 'America/Mexico_City',
          windows: <TimeWindow>[
            TimeWindow(days: <int>[1, 2], from: '18:00', to: '09:00'),
          ],
          onMatchStepId: 'sC',
          onElseStepId: 'sA',
        ),
      );

      expect(
        find.text('La hora de inicio debe ser anterior al final'),
        findsOneWidget,
      );
    });

    testWidgets('el motivo del bloqueo sale del textTheme (labelSmall)', (
      tester,
    ) async {
      await pumpForm(
        tester,
        initial: const ConditionalTimeMetadata(
          tz: 'America/Mexico_City',
          windows: <TimeWindow>[
            TimeWindow(days: <int>[1, 2], from: '18:00', to: '09:00'),
          ],
          onMatchStepId: 'sC',
          onElseStepId: 'sA',
        ),
      );

      final context = tester.element(find.byType(ConditionalTimeForm));
      final textTheme = Theme.of(context).textTheme;
      // Aviso inline = labelSmall del theme teñido a danger, no un calco
      // manual de captionSize/captionWeight.
      final reason = tester.widget<Text>(
        find.text('La hora de inicio debe ser anterior al final'),
      );
      expect(
        reason.style,
        textTheme.labelSmall?.copyWith(color: AppTokens.danger),
      );
    });

    testWidgets('ventana válida no muestra ningún aviso', (tester) async {
      await pumpForm(tester);

      expect(
        find.text('La hora de inicio debe ser anterior al final'),
        findsNothing,
      );
      expect(find.text('Selecciona al menos un día'), findsNothing);
    });
  });
}
