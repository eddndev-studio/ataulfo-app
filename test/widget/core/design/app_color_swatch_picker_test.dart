import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_color_swatch_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  );

  Widget dot(Color color) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  testWidgets('pinta una opción por swatch, cada una con su key', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AppColorSwatchPicker(
          options: <AppColorSwatchOption>[
            AppColorSwatchOption(
              key: const Key('picker.a'),
              swatch: dot(const Color(0xFF22C55E)),
              selected: false,
              onTap: () {},
            ),
            AppColorSwatchOption(
              key: const Key('picker.b'),
              swatch: dot(const Color(0xFF7C3AED)),
              selected: true,
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('picker.a')), findsOneWidget);
    expect(find.byKey(const Key('picker.b')), findsOneWidget);
  });

  testWidgets('tocar un swatch dispara su onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        AppColorSwatchPicker(
          options: <AppColorSwatchOption>[
            AppColorSwatchOption(
              key: const Key('picker.a'),
              swatch: dot(const Color(0xFF22C55E)),
              selected: false,
              onTap: () => tapped = true,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('picker.a')));
    expect(tapped, isTrue);
  });

  testWidgets('enabled=false bloquea el tap de todas las opciones', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        AppColorSwatchPicker(
          enabled: false,
          options: <AppColorSwatchOption>[
            AppColorSwatchOption(
              key: const Key('picker.a'),
              swatch: dot(const Color(0xFF22C55E)),
              selected: false,
              onTap: () => tapped = true,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('picker.a')));
    expect(tapped, isFalse);
  });

  testWidgets('el seleccionado lleva anillo de marca; el resto no', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AppColorSwatchPicker(
          options: <AppColorSwatchOption>[
            AppColorSwatchOption(
              key: const Key('picker.a'),
              swatch: dot(const Color(0xFF22C55E)),
              selected: false,
              onTap: () {},
            ),
            AppColorSwatchOption(
              key: const Key('picker.b'),
              swatch: dot(const Color(0xFF7C3AED)),
              selected: true,
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    BoxDecoration ringOf(String key) {
      // El primer Container bajo la opción (orden de árbol) es el anillo;
      // el swatch del consumidor vive dentro de él.
      final ring = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(Container),
            )
            .first,
      );
      return ring.decoration! as BoxDecoration;
    }

    final selected = ringOf('picker.b');
    final unselected = ringOf('picker.a');
    expect((selected.border! as Border).top.color, AppTokens.primary);
    expect((unselected.border! as Border).top.color, Colors.transparent);
  });

  testWidgets('cada opción reserva un objetivo táctil de 44x44', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AppColorSwatchPicker(
          options: <AppColorSwatchOption>[
            AppColorSwatchOption(
              key: const Key('picker.a'),
              swatch: dot(const Color(0xFF22C55E)),
              selected: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    final size = tester.getSize(find.byKey(const Key('picker.a')));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });
}
