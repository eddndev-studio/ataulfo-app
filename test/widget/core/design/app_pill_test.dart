import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';

void main() {
  Future<void> pumpPill(WidgetTester tester, Widget pill) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: pill)));
  }

  Container pillContainer(WidgetTester tester) {
    return tester.widget<Container>(
      find.descendant(
        of: find.byType(AppPill),
        matching: find.byType(Container),
      ),
    );
  }

  TextStyle? labelStyle(WidgetTester tester, String text) {
    return tester.widget<Text>(find.text(text)).style;
  }

  group('AppPill — variantes (fondo + color de label)', () {
    testWidgets('primary: fill amarillo sólido + texto onPrimary', (
      tester,
    ) async {
      await pumpPill(tester, const AppPill.primary(label: 'Activo'));
      final c = pillContainer(tester);
      final d = c.decoration as BoxDecoration;
      // Pill rellena de marca: fondo primary pleno, sin gradiente ni tint.
      expect(d.color, AppTokens.primary);
      expect(d.gradient, isNull);
      // Regla on-primary: texto oscuro sobre el fill cálido, nunca blanco.
      expect(labelStyle(tester, 'Activo')?.color, AppTokens.onPrimary);
    });

    testWidgets('neutral: fondo surface3 + fg text2', (tester) async {
      await pumpPill(tester, const AppPill.neutral(label: 'Pausado'));
      final c = pillContainer(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.color, AppTokens.surface3);
      expect(labelStyle(tester, 'Pausado')?.color, AppTokens.text2);
    });

    testWidgets('danger: tint rojo + fg danger', (tester) async {
      await pumpPill(tester, const AppPill.danger(label: 'Error'));
      final c = pillContainer(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.color, AppTokens.danger.withValues(alpha: 0.16));
      expect(labelStyle(tester, 'Error')?.color, AppTokens.danger);
    });

    testWidgets('outline: transparent + border 1px divider + fg text2', (
      tester,
    ) async {
      await pumpPill(tester, const AppPill.outline(label: 'v 1.2'));
      final c = pillContainer(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.color, Colors.transparent);
      expect(d.border?.top.color, AppTokens.divider);
      expect(d.border?.top.width, 1);
      expect(labelStyle(tester, 'v 1.2')?.color, AppTokens.text2);
    });

    testWidgets('glass: velo oscuro translúcido + fg onPrimary', (
      tester,
    ) async {
      await pumpPill(tester, const AppPill.glass(label: 'v3'));
      final c = pillContainer(tester);
      final d = c.decoration as BoxDecoration;
      // Cápsula de vidrio para fondos vivos (el gradiente de marca): velo
      // oscuro translúcido (onPrimary @ 0.16) con label onPrimary, hermana de
      // AppCard.glass. Sin gradiente propio.
      expect(d.color, AppTokens.onPrimary.withValues(alpha: 0.16));
      expect(d.gradient, isNull);
      expect(labelStyle(tester, 'v3')?.color, AppTokens.onPrimary);
    });
  });

  group('AppPill — geometría', () {
    testWidgets('padding 4/10 y radio pill (full)', (tester) async {
      await pumpPill(tester, const AppPill.neutral(label: 'x'));
      final c = pillContainer(tester);
      expect(
        c.padding,
        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      );
      final d = c.decoration as BoxDecoration;
      // Todas las variantes son cápsulas: radio full, no el chip de 8.
      expect(d.borderRadius, BorderRadius.circular(AppTokens.radiusPill));
    });

    testWidgets('outline también usa radio pill (full)', (tester) async {
      await pumpPill(tester, const AppPill.outline(label: 'x'));
      final c = pillContainer(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.borderRadius, BorderRadius.circular(AppTokens.radiusPill));
    });

    testWidgets('label en caption 12/16 weight 500', (tester) async {
      await pumpPill(tester, const AppPill.neutral(label: 'caption'));
      final s = labelStyle(tester, 'caption')!;
      expect(s.fontSize, AppTokens.captionSize);
      expect(s.fontWeight, AppTokens.captionWeight);
    });
  });

  group('AppPill — dot opcional', () {
    Finder dotFinder() => find.byKey(const ValueKey('app_pill.dot'));

    testWidgets('sin dot: no se renderiza', (tester) async {
      await pumpPill(tester, const AppPill.primary(label: 'sin dot'));
      expect(dotFinder(), findsNothing);
    });

    testWidgets('dot active en primary: círculo color onPrimary', (
      tester,
    ) async {
      await pumpPill(
        tester,
        const AppPill.primary(label: 'Activo', dot: AppPillDot.active),
      );
      final dot = tester.widget<Container>(dotFinder());
      final d = dot.decoration as BoxDecoration;
      // Sobre el fill amarillo el dot va oscuro (onPrimary) para contrastar.
      expect(d.color, AppTokens.onPrimary);
      expect(d.shape, BoxShape.circle);
    });

    testWidgets('dot active en neutral: círculo color accent', (tester) async {
      await pumpPill(
        tester,
        const AppPill.neutral(label: 'Activo', dot: AppPillDot.active),
      );
      final dot = tester.widget<Container>(dotFinder());
      final d = dot.decoration as BoxDecoration;
      expect(d.color, AppTokens.accent);
      expect(d.shape, BoxShape.circle);
    });

    testWidgets('dot paused: círculo color text2', (tester) async {
      await pumpPill(
        tester,
        const AppPill.neutral(label: 'Pausado', dot: AppPillDot.paused),
      );
      final dot = tester.widget<Container>(dotFinder());
      final d = dot.decoration as BoxDecoration;
      expect(d.color, AppTokens.text2);
    });

    testWidgets('dot danger: círculo color danger', (tester) async {
      await pumpPill(
        tester,
        const AppPill.danger(label: 'Error', dot: AppPillDot.danger),
      );
      final dot = tester.widget<Container>(dotFinder());
      final d = dot.decoration as BoxDecoration;
      expect(d.color, AppTokens.danger);
    });
  });

  group('AppPill — icon opcional', () {
    Finder iconFinder() =>
        find.descendant(of: find.byType(AppPill), matching: find.byType(Icon));

    testWidgets('sin icon: no se renderiza', (tester) async {
      await pumpPill(tester, const AppPill.neutral(label: 'sin icon'));
      expect(iconFinder(), findsNothing);
    });

    testWidgets('con icon: se renderiza antes del label, color del texto', (
      tester,
    ) async {
      await pumpPill(
        tester,
        const AppPill.neutral(label: 'v1.2', icon: Icons.tag),
      );
      final icon = tester.widget<Icon>(iconFinder());
      expect(icon.icon, Icons.tag);
      // El ícono espeja el color del label de la variante (neutral → text2).
      expect(icon.color, AppTokens.text2);
    });

    testWidgets('icon en primary hereda onPrimary (sobre fill cálido)', (
      tester,
    ) async {
      await pumpPill(
        tester,
        const AppPill.primary(label: 'Nuevo', icon: Icons.star),
      );
      final icon = tester.widget<Icon>(iconFinder());
      expect(icon.color, AppTokens.onPrimary);
    });

    testWidgets('icon y dot son mutuamente excluyentes (assert)', (
      tester,
    ) async {
      expect(
        () => AppPill.neutral(
          label: 'x',
          icon: Icons.tag,
          dot: AppPillDot.active,
        ),
        throwsAssertionError,
      );
    });
  });

  group('AppPill — a11y (estado verbalizado)', () {
    testWidgets('con dot active anuncia el estado "Activo"', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPill(
        tester,
        const AppPill.neutral(label: 'Etiqueta', dot: AppPillDot.active),
      );
      // El estado-por-color del dot debe ser anunciable junto al label visible.
      expect(find.bySemanticsLabel(RegExp('Activo')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('con dot paused anuncia el estado "Pausado"', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPill(
        tester,
        const AppPill.neutral(label: 'Etiqueta', dot: AppPillDot.paused),
      );
      expect(find.bySemanticsLabel(RegExp('Pausado')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('con dot danger anuncia el estado "Error"', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPill(
        tester,
        const AppPill.danger(label: 'Etiqueta', dot: AppPillDot.danger),
      );
      expect(find.bySemanticsLabel(RegExp('Error')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('sin dot no agrega Semantics de estado', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPill(tester, const AppPill.neutral(label: 'Etiqueta'));
      expect(find.bySemanticsLabel(RegExp('Activo')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Pausado')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Error')), findsNothing);
      handle.dispose();
    });
  });
}
