import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/app_radio.dart';

void main() {
  Future<void> pumpRadio(WidgetTester tester, Widget radio) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: radio)));
  }

  // El anillo exterior — círculo con borde — es el Container raíz pintado
  // dentro de AppRadio. Lo localizamos por key para no acoplar el test a la
  // profundidad del árbol (Opacity / GestureDetector envuelven el control).
  Container ringContainer(WidgetTester tester) {
    return tester.widget<Container>(
      find.byKey(const ValueKey('app_radio.ring')),
    );
  }

  // El punto interior relleno solo existe en estado seleccionado.
  Finder dotFinder() => find.byKey(const ValueKey('app_radio.dot'));

  group('AppRadio — render base', () {
    testWidgets('renderiza un único anillo circular', (tester) async {
      await pumpRadio(
        tester,
        AppRadio<int>(value: 0, groupValue: 1, onChanged: (_) {}),
      );
      expect(find.byType(AppRadio<int>), findsOneWidget);
      final d = ringContainer(tester).decoration as BoxDecoration;
      expect(d.shape, BoxShape.circle);
    });

    testWidgets('el control visible mide ~24', (tester) async {
      await pumpRadio(
        tester,
        AppRadio<int>(value: 0, groupValue: 1, onChanged: (_) {}),
      );
      final size = tester.getSize(find.byKey(const ValueKey('app_radio.ring')));
      expect(size.width, 24);
      expect(size.height, 24);
    });

    testWidgets('hit-target de al menos 48x48', (tester) async {
      await pumpRadio(
        tester,
        AppRadio<int>(value: 0, groupValue: 1, onChanged: (_) {}),
      );
      final size = tester.getSize(find.byType(AppRadio<int>));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('AppRadio — unselected vs selected', () {
    testWidgets('unselected (value != groupValue): borde neutral, sin punto', (
      tester,
    ) async {
      await pumpRadio(
        tester,
        AppRadio<int>(value: 0, groupValue: 1, onChanged: (_) {}),
      );
      final d = ringContainer(tester).decoration as BoxDecoration;
      // El anillo apagado usa un borde neutral visible (text2), nunca el
      // amarillo de marca que se reserva para el estado seleccionado.
      expect(d.border?.top.color, AppTokens.text2);
      // Interior relleno con la superficie elevada, no transparente.
      expect(d.color, AppTokens.surface3);
      expect(dotFinder(), findsNothing);
    });

    testWidgets('selected (value == groupValue): aparece el punto interior', (
      tester,
    ) async {
      await pumpRadio(
        tester,
        AppRadio<int>(value: 1, groupValue: 1, onChanged: (_) {}),
      );
      expect(dotFinder(), findsOneWidget);
    });
  });

  group('AppRadio — color de marca en selected', () {
    testWidgets('anillo relleno en primary', (tester) async {
      await pumpRadio(
        tester,
        AppRadio<int>(value: 1, groupValue: 1, onChanged: (_) {}),
      );
      final d = ringContainer(tester).decoration as BoxDecoration;
      // La figura se invierte: el anillo se rellena de marca.
      expect(d.color, AppTokens.primary);
    });

    testWidgets('punto interior oscuro (onPrimary) y circular', (tester) async {
      await pumpRadio(
        tester,
        AppRadio<int>(value: 1, groupValue: 1, onChanged: (_) {}),
      );
      final dot = tester.widget<Container>(dotFinder());
      final d = dot.decoration as BoxDecoration;
      // Punto oscuro al centro para contraste sobre el relleno amarillo.
      expect(d.color, AppTokens.onPrimary);
      expect(d.shape, BoxShape.circle);
    });
  });

  group('AppRadio — estado disabled', () {
    testWidgets('onChanged null: opacity 0.4', (tester) async {
      await pumpRadio(
        tester,
        const AppRadio<int>(value: 0, groupValue: 1, onChanged: null),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(AppRadio<int>),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.4);
    });

    testWidgets('onChanged null: el tap no dispara nada', (tester) async {
      // Sin callback no hay nada que invocar; el contrato es que el control
      // queda inerte. Verificamos que el tap no lanza excepción.
      await pumpRadio(
        tester,
        const AppRadio<int>(value: 0, groupValue: 1, onChanged: null),
      );
      await tester.tap(find.byType(AppRadio<int>));
      await tester.pump();
      // Sin aserción de error: pump sin excepción ya valida la inercia.
    });
  });

  group('AppRadio — interacción', () {
    testWidgets('tap sobre opción no seleccionada dispara onChanged(value)', (
      tester,
    ) async {
      int? recibido;
      await pumpRadio(
        tester,
        AppRadio<int>(
          value: 2,
          groupValue: 1,
          onChanged: (v) => recibido = v,
        ),
      );
      await tester.tap(find.byType(AppRadio<int>));
      await tester.pump();
      // Idioma de Radio de Flutter: el callback recibe el value del control.
      expect(recibido, 2);
    });
  });

  group('AppRadio — semántica', () {
    testWidgets('expone rol de radio en grupo exclusivo con estado', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpRadio(
        tester,
        AppRadio<int>(value: 1, groupValue: 1, onChanged: (_) {}),
      );
      expect(
        tester.getSemantics(find.byType(AppRadio<int>)),
        containsSemantics(
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('no seleccionado: isChecked false', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRadio(
        tester,
        AppRadio<int>(value: 1, groupValue: 2, onChanged: (_) {}),
      );
      expect(
        tester.getSemantics(find.byType(AppRadio<int>)),
        containsSemantics(isInMutuallyExclusiveGroup: true, isChecked: false),
      );
      handle.dispose();
    });
  });
}
