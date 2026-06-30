import 'dart:async';

import 'package:ataulfo/features/messages/presentation/widgets/live_waveform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveWaveform', () {
    testWidgets('renderiza y absorbe muestras sin reventar', (tester) async {
      final amp = StreamController<double>.broadcast();
      addTearDown(amp.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: LiveWaveform(amplitude: amp.stream),
            ),
          ),
        ),
      );

      amp.add(40);
      await tester.pump(const Duration(milliseconds: 50));
      amp.add(80);
      await tester.pump(const Duration(milliseconds: 50));
      // Asienta la animación de deslizamiento pendiente.
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en pausa ignora las muestras nuevas (no anima)', (
      tester,
    ) async {
      final amp = StreamController<double>.broadcast();
      addTearDown(amp.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: LiveWaveform(amplitude: amp.stream, paused: true),
            ),
          ),
        ),
      );

      amp.add(50);
      await tester.pump(const Duration(milliseconds: 50));
      // Pausado: no hay animación en vuelo que asentar; pumpAndSettle no cuelga.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancela la suscripción al desmontar', (tester) async {
      final amp = StreamController<double>.broadcast();
      addTearDown(amp.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: LiveWaveform(amplitude: amp.stream),
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      // Tras desmontar, una emisión no debe tocar estado desmontado.
      amp.add(70);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
