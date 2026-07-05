import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('tematiza el Slider con la paleta del kit', (tester) async {
    await tester.pumpWidget(host(AppSlider(value: 0.5, onChanged: (_) {})));

    // El primitivo existe para que ningún call site re-declare un SliderTheme
    // artesanal: track activo/thumb en primary, track inactivo en surface3 y
    // overlay del gesto en primary al 12%.
    final context = tester.element(find.byType(Slider));
    final theme = SliderTheme.of(context);
    expect(theme.activeTrackColor, AppTokens.primary);
    expect(theme.inactiveTrackColor, AppTokens.surface3);
    expect(theme.thumbColor, AppTokens.primary);
    expect(theme.overlayColor, AppTokens.primary.withValues(alpha: 0.12));
  });

  testWidgets('propaga min/max/divisions al Slider interno', (tester) async {
    await tester.pumpWidget(
      host(
        AppSlider(
          value: 12,
          min: 0,
          max: 120,
          divisions: 120,
          onChanged: (_) {},
        ),
      ),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 12);
    expect(slider.min, 0);
    expect(slider.max, 120);
    expect(slider.divisions, 120);
  });

  testWidgets('arrastrar dispara onChanged con el valor nuevo', (tester) async {
    double? changed;
    await tester.pumpWidget(
      host(
        AppSlider(
          value: 0,
          min: 0,
          max: 10,
          divisions: 10,
          onChanged: (v) => changed = v,
        ),
      ),
    );

    // Arrastre más allá del ancho del control → tope (max).
    await tester.drag(find.byType(AppSlider), const Offset(600, 0));
    expect(changed, 10);
  });

  testWidgets('onChanged null deshabilita el control', (tester) async {
    await tester.pumpWidget(host(const AppSlider(value: 0.5, onChanged: null)));

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.onChanged, isNull);
  });
}
