import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/app_switch.dart';

void main() {
  Future<void> pumpSwitch(WidgetTester tester, Widget sw) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: sw)));
  }

  // El knob vive dentro de un AnimatedAlign: leer su alignment devuelve el
  // valor objetivo de inmediato (sin pumpAndSettle), lo que cubre a la vez
  // "posición del knob" y "transición animada". Anclar los finds aquí evita
  // el multi-match que daría un find.byType(Container) crudo (track + knob).
  AnimatedAlign knobAlign(WidgetTester tester) {
    return tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
  }

  // Container del knob: descendiente del AnimatedAlign.
  Container knobContainer(WidgetTester tester) {
    return tester.widget<Container>(
      find.descendant(
        of: find.byType(AnimatedAlign),
        matching: find.byType(Container),
      ),
    );
  }

  // Container del track: ancestro del AnimatedAlign dentro del AppSwitch.
  Container trackContainer(WidgetTester tester) {
    return tester.widget<Container>(
      find
          .ancestor(
            of: find.byType(AnimatedAlign),
            matching: find.byType(Container),
          )
          .first,
    );
  }

  group('AppSwitch — render', () {
    testWidgets('renderiza track y knob (un AnimatedAlign en el árbol)', (
      tester,
    ) async {
      await pumpSwitch(
        tester,
        AppSwitch(value: false, onChanged: (_) {}),
      );
      expect(find.byType(AppSwitch), findsOneWidget);
      expect(find.byType(AnimatedAlign), findsOneWidget);
    });
  });

  group('AppSwitch — color del track', () {
    testWidgets('off: track surface3', (tester) async {
      await pumpSwitch(
        tester,
        AppSwitch(value: false, onChanged: (_) {}),
      );
      final d = trackContainer(tester).decoration as BoxDecoration;
      expect(d.color, AppTokens.surface3);
    });

    testWidgets('on: track primary (amarillo)', (tester) async {
      await pumpSwitch(
        tester,
        AppSwitch(value: true, onChanged: (_) {}),
      );
      final d = trackContainer(tester).decoration as BoxDecoration;
      expect(d.color, AppTokens.primary);
    });
  });

  group('AppSwitch — color del knob', () {
    testWidgets('off: knob claro (text1)', (tester) async {
      await pumpSwitch(
        tester,
        AppSwitch(value: false, onChanged: (_) {}),
      );
      final d = knobContainer(tester).decoration as BoxDecoration;
      expect(d.color, AppTokens.text1);
    });

    testWidgets('on: knob oscuro (onPrimary)', (tester) async {
      await pumpSwitch(
        tester,
        AppSwitch(value: true, onChanged: (_) {}),
      );
      final d = knobContainer(tester).decoration as BoxDecoration;
      expect(d.color, AppTokens.onPrimary);
    });
  });

  group('AppSwitch — posición y animación del knob', () {
    testWidgets('off: knob alineado a la izquierda', (tester) async {
      await pumpSwitch(
        tester,
        AppSwitch(value: false, onChanged: (_) {}),
      );
      expect(knobAlign(tester).alignment, Alignment.centerLeft);
    });

    testWidgets('on: knob alineado a la derecha', (tester) async {
      await pumpSwitch(
        tester,
        AppSwitch(value: true, onChanged: (_) {}),
      );
      expect(knobAlign(tester).alignment, Alignment.centerRight);
    });

    testWidgets('transición usa durationFast', (tester) async {
      await pumpSwitch(
        tester,
        AppSwitch(value: false, onChanged: (_) {}),
      );
      expect(knobAlign(tester).duration, AppTokens.durationFast);
    });
  });

  group('AppSwitch — estado disabled', () {
    testWidgets('onChanged null: opacity 0.4', (tester) async {
      await pumpSwitch(
        tester,
        const AppSwitch(value: false, onChanged: null),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(AppSwitch),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.4);
    });

    testWidgets('onChanged null: el tap no togglea', (tester) async {
      // Sin callback no hay contador que verificar; el contrato disabled es
      // visual (opacity) y la ausencia de toggle se garantiza con onTap null.
      await pumpSwitch(
        tester,
        const AppSwitch(value: false, onChanged: null),
      );
      await tester.tap(find.byType(AppSwitch));
      await tester.pump();
      // Sin excepción: el tap se absorbe. El knob permanece a la izquierda.
      expect(knobAlign(tester).alignment, Alignment.centerLeft);
    });

    testWidgets('habilitado: opacity 1.0', (tester) async {
      await pumpSwitch(
        tester,
        AppSwitch(value: false, onChanged: (_) {}),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(AppSwitch),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 1.0);
    });
  });

  group('AppSwitch — tap togglea', () {
    testWidgets('off → on: tap dispara onChanged(true)', (tester) async {
      bool? recibido;
      await pumpSwitch(
        tester,
        AppSwitch(value: false, onChanged: (v) => recibido = v),
      );
      await tester.tap(find.byType(AppSwitch));
      await tester.pump();
      expect(recibido, true);
    });

    testWidgets('on → off: tap dispara onChanged(false)', (tester) async {
      // Probar ambas direcciones pin-ea onChanged(!value) en lugar de un
      // valor hardcodeado.
      bool? recibido;
      await pumpSwitch(
        tester,
        AppSwitch(value: true, onChanged: (v) => recibido = v),
      );
      await tester.tap(find.byType(AppSwitch));
      await tester.pump();
      expect(recibido, false);
    });
  });
}
