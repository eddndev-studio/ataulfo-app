import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_checkbox.dart';

void main() {
  Future<void> pumpCheckbox(WidgetTester tester, Widget checkbox) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: checkbox)));
  }

  // La caja visual es el Container decorado con el radio del control. El árbol
  // contiene otros Containers (Material/InkWell internos) sin decoración con
  // borderRadius, así que filtramos por la decoración que define el contrato.
  BoxDecoration controlDecoration(WidgetTester tester) {
    final containers = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(AppCheckbox),
        matching: find.byType(Container),
      ),
    );
    final box = containers.firstWhere((c) {
      final d = c.decoration;
      return d is BoxDecoration &&
          d.borderRadius == BorderRadius.circular(AppTokens.radiusSm);
    });
    return box.decoration as BoxDecoration;
  }

  group('AppCheckbox — render base', () {
    testWidgets('renderiza un único control en el árbol', (tester) async {
      await pumpCheckbox(
        tester,
        AppCheckbox(value: false, onChanged: (_) {}),
      );
      expect(find.byType(AppCheckbox), findsOneWidget);
    });

    testWidgets('caja con radio radiusSm (8)', (tester) async {
      await pumpCheckbox(
        tester,
        AppCheckbox(value: false, onChanged: (_) {}),
      );
      final d = controlDecoration(tester);
      expect(d.borderRadius, BorderRadius.circular(AppTokens.radiusSm));
    });

    testWidgets('hit-target de al menos 48', (tester) async {
      await pumpCheckbox(
        tester,
        AppCheckbox(value: false, onChanged: (_) {}),
      );
      final size = tester.getSize(find.byType(AppCheckbox));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('AppCheckbox — color unchecked vs checked', () {
    testWidgets('unchecked: fondo surface3 con borde divider', (
      tester,
    ) async {
      await pumpCheckbox(
        tester,
        AppCheckbox(value: false, onChanged: (_) {}),
      );
      final d = controlDecoration(tester);
      expect(d.color, AppTokens.surface3);
      // El borde delinea la caja llena contra la superficie.
      expect(d.border, isNotNull);
      expect((d.border as Border).top.color, AppTokens.divider);
    });

    testWidgets('checked: fondo primary (amarillo)', (tester) async {
      await pumpCheckbox(
        tester,
        AppCheckbox(value: true, onChanged: (_) {}),
      );
      final d = controlDecoration(tester);
      expect(d.color, AppTokens.primary);
    });
  });

  group('AppCheckbox — presencia del check', () {
    testWidgets('unchecked: no hay Icon de check', (tester) async {
      await pumpCheckbox(
        tester,
        AppCheckbox(value: false, onChanged: (_) {}),
      );
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('checked: muestra Icon de check en onPrimary (oscuro)', (
      tester,
    ) async {
      await pumpCheckbox(
        tester,
        AppCheckbox(value: true, onChanged: (_) {}),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(icon.color, AppTokens.onPrimary);
    });
  });

  group('AppCheckbox — estado disabled', () {
    testWidgets('onChanged null: opacity 0.4', (tester) async {
      await pumpCheckbox(
        tester,
        const AppCheckbox(value: false, onChanged: null),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(AppCheckbox),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.4);
    });

    testWidgets('onChanged null: el tap no togglea', (tester) async {
      // Sin callback no hay forma de mutar el estado; el contrato es que el
      // tap quede inerte (InkWell.onTap null), igual que AppButton disabled.
      await pumpCheckbox(
        tester,
        const AppCheckbox(value: false, onChanged: null),
      );
      await tester.tap(find.byType(AppCheckbox));
      await tester.pumpAndSettle();
      // El control sigue unchecked: ni fondo primary ni check presentes.
      final d = controlDecoration(tester);
      expect(d.color, AppTokens.surface3);
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });

  group('AppCheckbox — toggle', () {
    testWidgets('tap sobre unchecked dispara onChanged(true)', (tester) async {
      bool? recibido;
      await pumpCheckbox(
        tester,
        AppCheckbox(value: false, onChanged: (v) => recibido = v),
      );
      await tester.tap(find.byType(AppCheckbox));
      await tester.pumpAndSettle();
      expect(recibido, isTrue);
    });

    testWidgets('tap sobre checked dispara onChanged(false)', (tester) async {
      bool? recibido;
      await pumpCheckbox(
        tester,
        AppCheckbox(value: true, onChanged: (v) => recibido = v),
      );
      await tester.tap(find.byType(AppCheckbox));
      await tester.pumpAndSettle();
      expect(recibido, isFalse);
    });
  });

  group('AppCheckbox — semántica', () {
    testWidgets('expone rol de casilla con estado y habilitación', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCheckbox(tester, AppCheckbox(value: true, onChanged: (_) {}));
      expect(
        tester.getSemantics(find.byType(AppCheckbox)),
        containsSemantics(
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('disabled (onChanged null): casilla no habilitada', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCheckbox(
        tester,
        const AppCheckbox(value: false, onChanged: null),
      );
      expect(
        tester.getSemantics(find.byType(AppCheckbox)),
        containsSemantics(
          hasCheckedState: true,
          isChecked: false,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });
  });
}
