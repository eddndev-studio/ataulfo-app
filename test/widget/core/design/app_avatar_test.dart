import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';

// PNG válido de 1×1 transparente: bytes decodificables para que el Image no
// dispare el errorBuilder y ensucie el log (la aserción mira el Image, no el
// pixel).
final _png1x1 = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
]);

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

    testWidgets('relleno del fallback tomado de la paleta determinista', (
      tester,
    ) async {
      // Sin aro, el relleno del fallback sin foto es un color de la paleta de
      // avatar (elegido de forma determinista por contacto), no una superficie
      // fija del kit.
      await pumpAvatar(tester, const AppAvatar(name: 'a'));

      final decoration = rootContainer(tester).decoration as BoxDecoration;
      expect(AppTokens.avatarFallbackPalette, contains(decoration.color));
    });

    testWidgets('sin anillo: el avatar no tiene borde', (tester) async {
      // El re-skin retira el aro amarillo perimetral: foto/relleno a círculo
      // completo, sin borde (un anillo competía con la foto y dejaba un halo
      // fantasma si solo se cambiaba el color).
      await pumpAvatar(tester, const AppAvatar(name: 'a'));

      final decoration = rootContainer(tester).decoration as BoxDecoration;
      expect(decoration.border, isNull);
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

  group('AppAvatar — foto (imageUrl)', () {
    testWidgets('con imageUrl renderiza un Image.network', (tester) async {
      await pumpAvatar(
        tester,
        const AppAvatar(name: 'a', imageUrl: 'https://cdn.test/p.jpg'),
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('la foto ocupa el círculo completo', (tester) async {
      // Sin aro, la foto se dimensiona al diámetro completo y se recorta en
      // círculo (ClipOval); ya no se inserta con el padding del grosor del aro.
      await pumpAvatar(
        tester,
        const AppAvatar(
          name: 'a',
          size: 64,
          imageUrl: 'https://cdn.test/p.jpg',
        ),
      );
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.width, 64);
    });

    testWidgets('foto que no carga cae a la inicial (errorBuilder)', (
      tester,
    ) async {
      // En tests Image.network falla (sin red real); el errorBuilder es el
      // fallback que importa cuando la foto está rota o el CDN no responde:
      // debe mostrar la inicial, no un hueco ni un glifo roto.
      await pumpAvatar(
        tester,
        const AppAvatar(name: 'a', imageUrl: 'https://invalid.test/falla.jpg'),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('A'), findsOneWidget);
    });
  });

  group('AppAvatar — foto (imageProvider)', () {
    testWidgets('con imageProvider renderiza un Image (foto local cacheada)', (
      tester,
    ) async {
      await pumpAvatar(
        tester,
        AppAvatar(name: 'a', imageProvider: MemoryImage(_png1x1)),
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('sin url ni provider muestra la inicial (sin Image)', (
      tester,
    ) async {
      await pumpAvatar(tester, const AppAvatar(name: 'ada'));
      expect(find.byType(Image), findsNothing);
      expect(find.text('A'), findsOneWidget);
    });
  });

  group('AppAvatar — color determinista', () {
    // Réplica del hash del widget (FNV-1a) para fijar el contrato: si el widget
    // cambiara de algoritmo, el color esperado dejaría de coincidir.
    int refIndex(String key) {
      var hash = 0x811c9dc5;
      for (final r in key.runes) {
        hash = ((hash ^ r) * 0x01000193) & 0xFFFFFFFF;
      }
      return hash % AppTokens.avatarFallbackPalette.length;
    }

    testWidgets('colorKey fija el color (FNV-1a) e ignora el name', (
      tester,
    ) async {
      const key = 'chat-lid-42';
      final expected = AppTokens.avatarFallbackPalette[refIndex(key)];

      await pumpAvatar(
        tester,
        const AppAvatar(name: 'Cargando…', colorKey: key),
      );
      expect(
        (rootContainer(tester).decoration as BoxDecoration).color,
        expected,
      );

      // Mismo colorKey, name distinto → mismo color: estable en la transición
      // placeholder→nombre real y entre dispositivos.
      await pumpAvatar(
        tester,
        const AppAvatar(name: 'Nombre Real', colorKey: key),
      );
      expect(
        (rootContainer(tester).decoration as BoxDecoration).color,
        expected,
      );
    });

    testWidgets('sin colorKey deriva del name (último recurso)', (
      tester,
    ) async {
      const name = 'Ventas MX';
      final expected = AppTokens.avatarFallbackPalette[refIndex(name)];
      await pumpAvatar(tester, const AppAvatar(name: name));
      expect(
        (rootContainer(tester).decoration as BoxDecoration).color,
        expected,
      );
    });

    test(
      'cada tono de la paleta conserva ≥4.5:1 contra la inicial (text1)',
      () {
        double ratio(Color a, Color b) {
          final la = a.computeLuminance();
          final lb = b.computeLuminance();
          final hi = la > lb ? la : lb;
          final lo = la > lb ? lb : la;
          return (hi + 0.05) / (lo + 0.05);
        }

        for (final c in AppTokens.avatarFallbackPalette) {
          expect(
            ratio(c, AppTokens.text1),
            greaterThanOrEqualTo(4.5),
            reason: 'tono $c bajo el mínimo AA contra text1',
          );
        }
      },
    );
  });
}
