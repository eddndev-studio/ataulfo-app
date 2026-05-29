import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/app_button.dart';

void main() {
  Future<void> pumpButton(WidgetTester tester, Widget button) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: button)));
  }

  Container rootContainer(WidgetTester tester) {
    return tester.widget<Container>(
      find.descendant(
        of: find.byType(AppButton),
        matching: find.byType(Container),
      ),
    );
  }

  group('AppButton — variantes', () {
    testWidgets('filled: fondo gradiente de marca, label en onPrimary', (
      tester,
    ) async {
      await pumpButton(
        tester,
        AppButton.filled(label: 'Crear', onPressed: () {}),
      );
      final c = rootContainer(tester);
      final d = c.decoration as BoxDecoration;
      // El fill es el gradiente de marca (primary→accent): la BoxDecoration
      // pinta con gradient, no con un color sólido. Ambas constraints son
      // reales — gradient presente y color ausente.
      expect(d.gradient, AppTokens.brandGradient);
      expect(d.color, isNull);
      // El amarillo exige primer plano oscuro para contraste: onPrimary.
      final label = tester.widget<Text>(find.text('Crear'));
      expect(label.style?.color, AppTokens.onPrimary);
    });

    testWidgets('tonal: fondo surface2, label en text1', (tester) async {
      await pumpButton(
        tester,
        AppButton.tonal(label: 'Pausar', onPressed: () {}),
      );
      final c = rootContainer(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.color, AppTokens.surface2);
      final label = tester.widget<Text>(find.text('Pausar'));
      expect(label.style?.color, AppTokens.text1);
    });

    testWidgets('text: fondo transparent, label en primary', (tester) async {
      await pumpButton(
        tester,
        AppButton.text(label: 'Copiar', onPressed: () {}),
      );
      final c = rootContainer(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.color, Colors.transparent);
      final label = tester.widget<Text>(find.text('Copiar'));
      expect(label.style?.color, AppTokens.primary);
    });

    testWidgets('danger: fondo transparent, label en danger', (tester) async {
      await pumpButton(
        tester,
        AppButton.danger(label: 'Eliminar', onPressed: () {}),
      );
      final c = rootContainer(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.color, Colors.transparent);
      final label = tester.widget<Text>(find.text('Eliminar'));
      expect(label.style?.color, AppTokens.danger);
    });
  });

  group('AppButton — geometría', () {
    testWidgets('altura mínima 48 + radio pill (999)', (tester) async {
      await pumpButton(tester, AppButton.filled(label: 'X', onPressed: () {}));
      final c = rootContainer(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.borderRadius, BorderRadius.circular(AppTokens.radiusButton));
      // height de 48 lo enforce un ConstrainedBox con minHeight.
      final box = tester.getSize(find.byType(AppButton));
      expect(box.height, greaterThanOrEqualTo(48));
    });

    testWidgets('fullWidth: ocupa todo el ancho disponible', (tester) async {
      await pumpButton(
        tester,
        SizedBox(
          width: 400,
          child: AppButton.filled(
            label: 'X',
            onPressed: () {},
            fullWidth: true,
          ),
        ),
      );
      final size = tester.getSize(find.byType(AppButton));
      expect(size.width, 400);
    });

    testWidgets('default: NO ocupa todo el ancho disponible', (tester) async {
      await pumpButton(
        tester,
        SizedBox(
          width: 400,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppButton.filled(label: 'X', onPressed: () {}),
          ),
        ),
      );
      final size = tester.getSize(find.byType(AppButton));
      expect(size.width, lessThan(400));
    });
  });

  group('AppButton — estados', () {
    testWidgets('onPressed null: opacity 0.4 y no tappable', (tester) async {
      await pumpButton(
        tester,
        const AppButton.filled(label: 'X', onPressed: null),
      );
      // onPressed null bloquea el tap; verificación visual es la opacity
      // descrita abajo. No hace falta un contador porque no hay callback
      // que pudiera ser llamado.
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      // Opacity widget alrededor.
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.4);
    });

    testWidgets('onPressed asignado: tap dispara callback', (tester) async {
      var taps = 0;
      await pumpButton(
        tester,
        AppButton.filled(label: 'X', onPressed: () => taps++),
      );
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('AppButton — icono opcional', () {
    testWidgets('sin icon: no hay Icon en el árbol', (tester) async {
      await pumpButton(
        tester,
        AppButton.filled(label: 'Sin icon', onPressed: () {}),
      );
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('con icon: renderiza Icon a la izquierda del label', (
      tester,
    ) async {
      await pumpButton(
        tester,
        AppButton.filled(label: 'Crear', icon: Icons.add, onPressed: () {}),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.add));
      // Ícono sobre el fill cálido: onPrimary (oscuro), nunca blanco.
      expect(icon.color, AppTokens.onPrimary);
    });
  });

  group('AppButton — loading state', () {
    testWidgets('loading: false (default) renderiza el label como hasta hoy', (
      tester,
    ) async {
      await pumpButton(
        tester,
        AppButton.filled(label: 'Crear', onPressed: () {}),
      );
      expect(find.text('Crear'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('loading: true muestra spinner inline y oculta label e icon', (
      tester,
    ) async {
      await pumpButton(
        tester,
        AppButton.filled(
          label: 'Crear',
          icon: Icons.add,
          onPressed: () {},
          loading: true,
        ),
      );
      // El spinner comunica el estado de submitting; label + icon se
      // ocultan para no competir con el feedback visual.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Crear'), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets(
      'loading: true en variante filled tinte el spinner con onPrimary',
      (tester) async {
        // El spinner toma el foreground de la variante — coherente con el
        // color del label que reemplaza. En filled, foreground = onPrimary
        // (oscuro), para contrastar contra el fill cálido del gradiente.
        await pumpButton(
          tester,
          AppButton.filled(label: 'X', onPressed: () {}, loading: true),
        );
        final spinner = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(spinner.valueColor?.value, AppTokens.onPrimary);
      },
    );

    testWidgets('loading: true bloquea el tap sin nullificar onPressed', (
      tester,
    ) async {
      // Contrato del API: el consumidor pasa onPressed: _submit sin gate
      // !submitting; el botón ignora el tap internamente cuando loading
      // es true. Así los formularios no replican la rama en cada page.
      var taps = 0;
      await pumpButton(
        tester,
        AppButton.filled(label: 'X', onPressed: () => taps++, loading: true),
      );
      await tester.tap(find.byType(AppButton));
      // pumpAndSettle nunca termina con el spinner animado en pantalla;
      // un pump es suficiente para que el tap se procese si lo fuera.
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets(
      'loading: true mantiene opacity 1.0 (el spinner ya comunica el estado)',
      (tester) async {
        await pumpButton(
          tester,
          AppButton.filled(label: 'X', onPressed: () {}, loading: true),
        );
        final opacity = tester.widget<Opacity>(
          find.descendant(
            of: find.byType(AppButton),
            matching: find.byType(Opacity),
          ),
        );
        // Opacity baja a 0.4 solo cuando el botón está realmente disabled
        // (onPressed=null). Loading conserva el botón en su tinte pleno.
        expect(opacity.opacity, 1.0);
      },
    );
  });
}
