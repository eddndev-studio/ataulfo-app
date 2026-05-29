import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';

void main() {
  Future<void> pumpAvatar(WidgetTester tester, Widget w) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));
  }

  // El decorado vive en el Container raíz del avatar (descendiente directo
  // del widget). Centralizamos el lookup como en el resto de los tests del kit.
  Container rootContainer(WidgetTester tester) {
    return tester.widget<Container>(
      find.descendant(
        of: find.byType(AppAvatar),
        matching: find.byType(Container),
      ),
    );
  }

  group('AppAvatar — inicial', () {
    testWidgets('toma la primera letra en uppercase', (tester) async {
      await pumpAvatar(tester, const AppAvatar(name: 'soporte'));
      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('trim previo a tomar la inicial', (tester) async {
      await pumpAvatar(tester, const AppAvatar(name: '  ventas'));
      expect(find.text('V'), findsOneWidget);
    });

    testWidgets("vacío o solo espacios cae a '?'", (tester) async {
      await pumpAvatar(tester, const AppAvatar(name: '   '));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('toma el primer cluster de grafemas (no parte surrogates)', (
      tester,
    ) async {
      // Un substring por code unit partiría el emoji a la mitad y rendería un
      // glifo roto; el primer cluster de grafemas lo conserva entero.
      await pumpAvatar(tester, const AppAvatar(name: '👍team'));
      expect(find.text('👍'), findsOneWidget);
    });
  });

  group('AppAvatar — estilo', () {
    testWidgets('container circular', (tester) async {
      await pumpAvatar(tester, const AppAvatar(name: 'a'));

      final decoration = rootContainer(tester).decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('interior en superficie oscura del kit (surface2/surface3)', (
      tester,
    ) async {
      // El anillo amarillo es el protagonista; el relleno se mantiene en una
      // superficie oscura para que la inicial y el borde resalten. El kit
      // admite tanto surface2 como surface3 para este relleno.
      await pumpAvatar(tester, const AppAvatar(name: 'a'));

      final decoration = rootContainer(tester).decoration as BoxDecoration;
      expect(decoration.color, anyOf(AppTokens.surface2, AppTokens.surface3));
    });

    testWidgets('anillo: borde primary alrededor del avatar', (tester) async {
      // Detalle nuevo del re-skin (UserIcon): un anillo amarillo perimetral.
      await pumpAvatar(tester, const AppAvatar(name: 'a'));

      final decoration = rootContainer(tester).decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.border?.top.color, AppTokens.primary);
      expect(decoration.border?.top.width, greaterThan(0));
    });

    testWidgets(
      'label DMSans/w600 con text1, fontSize escala con el diámetro',
      (tester) async {
        // size 64 → 64 * 0.4 = 25.6: un valor que NO coincide con bodyLSize,
        // de modo que la aserción fija el escalado proporcional y no un tamaño
        // constante.
        await pumpAvatar(tester, const AppAvatar(name: 'a', size: 64));

        final style = tester.widget<Text>(find.text('A')).style;
        expect(style?.fontFamily, AppTokens.fontSans);
        expect(style?.fontSize, 64 * 0.4);
        expect(style?.fontWeight, FontWeight.w600);
        expect(style?.color, AppTokens.text1);
      },
    );
  });

  group('AppAvatar — accesibilidad', () {
    testWidgets('anuncia el nombre completo, no la inicial suelta', (
      tester,
    ) async {
      await pumpAvatar(tester, const AppAvatar(name: 'soporte'));

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(AppAvatar),
          matching: find.byType(Semantics),
        ),
      );
      expect(semantics.properties.label, 'soporte');
    });
  });

  group('AppAvatar — tamaño', () {
    testWidgets('default size 40x40', (tester) async {
      await pumpAvatar(tester, const AppAvatar(name: 'a'));
      final container = rootContainer(tester);
      expect(container.constraints?.maxWidth, 40);
      expect(container.constraints?.maxHeight, 40);
    });

    testWidgets('size custom respeta el parámetro', (tester) async {
      await pumpAvatar(tester, const AppAvatar(name: 'a', size: 64));
      final container = rootContainer(tester);
      expect(container.constraints?.maxWidth, 64);
      expect(container.constraints?.maxHeight, 64);
    });
  });
}
