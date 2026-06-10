import 'dart:convert';

import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_choice_chip.dart';
import 'package:ataulfo/features/flows/domain/entities/conditional_time_metadata.dart';
import 'package:ataulfo/features/flows/presentation/widgets/conditional_time_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper para montar el form aislado y capturar el último `onChanged`.
class CaptureSink {
  String? last;
  int calls = 0;
}

Future<CaptureSink> pumpForm(
  WidgetTester tester, {
  ConditionalTimeMetadata? initial,
  List<int> availableOrders = const <int>[0, 1, 2],
  bool enabled = true,
}) async {
  tester.view.physicalSize = const Size(1000, 1600);
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
            availableStepOrders: availableOrders,
            enabled: enabled,
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

void main() {
  group('ConditionalTimeForm (create con seed)', () {
    testWidgets(
      'mount inicial → onChanged emite metadataJson válido con defaults '
      '(L-V 09:00-18:00, tz America/Mexico_City)',
      (tester) async {
        final cap = await pumpForm(tester);

        expect(cap.last, isNotNull);
        final md = ConditionalTimeMetadata.fromJsonString(cap.last!);
        expect(md.tz, 'America/Mexico_City');
        expect(md.windows, hasLength(1));
        // Wire days L-V = [1,2,3,4,5] (Lun=1..Vie=5 en time.Weekday).
        expect(md.windows.first.days, <int>[1, 2, 3, 4, 5]);
        expect(md.windows.first.from, '09:00');
        expect(md.windows.first.to, '18:00');
        expect(md.onMatchOrder, 0);
        expect(md.onElseOrder, 1);
      },
    );

    testWidgets(
      'usa componentes del design system (AppChoiceChip días, AppButton '
      'horas y agregar ventana)',
      (tester) async {
        await pumpForm(tester);

        // Los chips de día son AppChoiceChip controlados.
        expect(
          tester.widget(find.byKey(const Key('ct_form.window.0.day.0'))),
          isA<AppChoiceChip>(),
        );
        // Los botones de hora desde/hasta son AppButton tonales.
        expect(
          tester.widget(find.byKey(const Key('ct_form.window.0.from'))),
          isA<AppButton>(),
        );
        expect(
          tester.widget(find.byKey(const Key('ct_form.window.0.to'))),
          isA<AppButton>(),
        );
        // Agregar ventana es un AppButton de texto.
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
        // Estado inicial es válido.
        expect(cap.last, isNotNull);

        // Destildo los 5 chips L-V (uiIndex 0..4).
        for (final uiIdx in <int>[0, 1, 2, 3, 4]) {
          await tester.tap(find.byKey(Key('ct_form.window.0.day.$uiIdx')));
          await tester.pump();
        }
        expect(cap.last, isNull, reason: 'sin días, metadataJson inválido');
      },
    );

    testWidgets(
      'agregar Sábado (uiIndex 5) → onChanged emite metadataJson con wireDay 6',
      (tester) async {
        final cap = await pumpForm(tester);
        await tester.tap(find.byKey(const Key('ct_form.window.0.day.5')));
        await tester.pump();

        expect(cap.last, isNotNull);
        final md = ConditionalTimeMetadata.fromJsonString(cap.last!);
        // L-V + S = days [1,2,3,4,5,6] (Sáb=6 en wire).
        expect(md.windows.first.days, <int>[1, 2, 3, 4, 5, 6]);
      },
    );

    testWidgets(
      'agregar Domingo (uiIndex 6) → wireDay 0 al inicio de la lista ordenada',
      (tester) async {
        final cap = await pumpForm(tester);
        await tester.tap(find.byKey(const Key('ct_form.window.0.day.6')));
        await tester.pump();

        expect(cap.last, isNotNull);
        final md = ConditionalTimeMetadata.fromJsonString(cap.last!);
        // L-V + D = days incluyen 0 (Dom). El form ordena ascendente.
        expect(md.windows.first.days, <int>[0, 1, 2, 3, 4, 5]);
      },
    );
  });

  group('ConditionalTimeForm (initial pre-cargado)', () {
    testWidgets(
      'monta con initial → onChanged emite metadataJson igual al initial',
      (tester) async {
        const initial = ConditionalTimeMetadata(
          tz: 'UTC',
          windows: <TimeWindow>[
            TimeWindow(days: <int>[0, 6], from: '10:00', to: '12:00'),
          ],
          onMatchOrder: 2,
          onElseOrder: 0,
        );
        final cap = await pumpForm(
          tester,
          initial: initial,
          availableOrders: <int>[0, 1, 2, 3],
        );

        expect(cap.last, isNotNull);
        final md = ConditionalTimeMetadata.fromJsonString(cap.last!);
        expect(md.tz, 'UTC');
        expect(md.onMatchOrder, 2);
        expect(md.onElseOrder, 0);
        expect(md.windows.first.days, <int>[0, 6]);
        expect(md.windows.first.from, '10:00');
        expect(md.windows.first.to, '12:00');
      },
    );

    testWidgets('cambio del dropdown TZ → onChanged emite con nuevo tz', (
      tester,
    ) async {
      final cap = await pumpForm(tester);
      final before = jsonDecode(cap.last!) as Map<String, dynamic>;
      expect(before['tz'], 'America/Mexico_City');

      // Abrir dropdown TZ y elegir UTC.
      await tester.tap(find.byKey(const Key('ct_form.tz_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UTC').last);
      await tester.pumpAndSettle();

      expect(cap.last, isNotNull);
      final after = jsonDecode(cap.last!) as Map<String, dynamic>;
      expect(after['tz'], 'UTC');
    });
  });

  group('ConditionalTimeForm (dropdowns onMatch/onElse)', () {
    testWidgets(
      'cambio del dropdown onMatch → onChanged emite con nuevo on_match_order',
      (tester) async {
        final cap = await pumpForm(tester, availableOrders: <int>[0, 1, 2, 3]);
        await tester.tap(find.byKey(const Key('ct_form.on_match_dropdown')));
        await tester.pumpAndSettle();
        // "Paso #3" en la UI = order=2 (display es order+1).
        await tester.tap(find.text('Paso #3').last);
        await tester.pumpAndSettle();

        final md = ConditionalTimeMetadata.fromJsonString(cap.last!);
        expect(md.onMatchOrder, 2);
      },
    );

    testWidgets(
      'lista de orders vacía → dropdowns deshabilitados pero form no crashea',
      (tester) async {
        final cap = await pumpForm(tester, availableOrders: const <int>[]);
        // Form sigue válido (defaults onMatch=0/onElse=1 — el operador
        // puede crear el CT primero y agregar steps destino después).
        expect(cap.last, isNotNull);
      },
    );
  });

  group('ConditionalTimeForm (multi-ventana)', () {
    testWidgets(
      'botón "Agregar ventana" añade ventana extra y onChanged la incluye',
      (tester) async {
        final cap = await pumpForm(tester);
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
        // Las dos ventanas chequean días vía keys ct_form.window.0.* y .1.*
        expect(find.byKey(const Key('ct_form.window.1.day.0')), findsOneWidget);
      },
    );

    testWidgets('botón "Eliminar ventana" desaparece cuando queda una sola; '
        'con dos, elimina la segunda', (tester) async {
      final cap = await pumpForm(tester);
      // Una sola → el botón remove de la 0 no aparece (no se puede dejar 0).
      expect(find.byKey(const Key('ct_form.window.0.remove')), findsNothing);

      // Agrego una ventana.
      await tester.tap(find.byKey(const Key('ct_form.add_window')));
      await tester.pump();
      // Ahora aparecen ambos remove.
      expect(find.byKey(const Key('ct_form.window.0.remove')), findsOneWidget);
      expect(find.byKey(const Key('ct_form.window.1.remove')), findsOneWidget);

      // Elimino la 1.
      await tester.tap(find.byKey(const Key('ct_form.window.1.remove')));
      await tester.pump();
      final md = ConditionalTimeMetadata.fromJsonString(cap.last!);
      expect(md.windows, hasLength(1));
    });
  });

  group('aviso inline de ventana inválida (barrido UX)', () {
    testWidgets('desde ≥ hasta muestra el motivo del bloqueo', (tester) async {
      // Sin este aviso el guardado se bloquea (toWireOrNull = null) sin que
      // el operador sepa por qué.
      await pumpForm(
        tester,
        initial: const ConditionalTimeMetadata(
          tz: 'America/Mexico_City',
          windows: <TimeWindow>[
            TimeWindow(days: <int>[1, 2], from: '18:00', to: '09:00'),
          ],
          onMatchOrder: 0,
          onElseOrder: 1,
        ),
      );

      expect(
        find.text('La hora de inicio debe ser anterior al final'),
        findsOneWidget,
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
