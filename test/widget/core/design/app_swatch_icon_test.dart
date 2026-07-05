import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_swatch_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('pinta el glifo en el color pleno sobre un velo tintado', (
    tester,
  ) async {
    const color = Color(0xFF7C3AED);
    await tester.pumpWidget(
      host(const AppSwatchIcon(color: color, icon: Icons.label_outline)),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.label_outline));
    expect(icon.color, color);

    // El velo de fondo es el MISMO color con alpha bajo: identidad cromática
    // sin gritar sobre el tema oscuro.
    final box = tester.widget<Container>(
      find.byKey(const Key('app_swatch_icon.tile')),
    );
    final deco = box.decoration! as BoxDecoration;
    expect(deco.shape, BoxShape.circle);
    final bg = deco.color!;
    expect(bg.toARGB32() & 0x00FFFFFF, color.toARGB32() & 0x00FFFFFF);
    expect(bg.a, lessThan(0.5));
  });

  testWidgets('tamaño por defecto 44 (paridad con AppEntityIcon)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const AppSwatchIcon(color: Color(0xFF22C55E))),
    );

    final size = tester.getSize(find.byKey(const Key('app_swatch_icon.tile')));
    expect(size.width, 44);
    expect(size.height, 44);
  });

  testWidgets(
    'la vía neutra pinta relleno surface3 opaco + glifo text2 (sin color)',
    (tester) async {
      await tester.pumpWidget(
        host(
          const AppSwatchIcon.neutral(
            icon: Icons.insert_drive_file_outlined,
            size: 56,
          ),
        ),
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.insert_drive_file_outlined),
      );
      expect(icon.color, AppTokens.text2);

      final box = tester.widget<Container>(
        find.byKey(const Key('app_swatch_icon.tile')),
      );
      final deco = box.decoration! as BoxDecoration;
      expect(deco.shape, BoxShape.circle);
      // Fondo neutro opaco (no un velo tintado): el círculo del kit para
      // destinos sin identidad cromática propia.
      expect(deco.color, AppTokens.surface3);

      final size = tester.getSize(
        find.byKey(const Key('app_swatch_icon.tile')),
      );
      expect(size.width, 56);
    },
  );
}
