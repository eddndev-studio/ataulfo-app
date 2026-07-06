import 'package:ataulfo/core/design/motion.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Sonda: captura lo que el kit vería en ese punto del árbol.
  Widget probe(void Function(BuildContext context) onBuild) => MaterialApp(
    home: Builder(
      builder: (context) {
        onBuild(context);
        return const SizedBox.shrink();
      },
    ),
  );

  testWidgets('sin AppMotion en el árbol las animaciones están encendidas '
      '(los tests y pages sueltas no cambian de conducta)', (tester) async {
    late bool enabled;
    await tester.pumpWidget(probe((ctx) => enabled = AppMotion.enabledOf(ctx)));
    expect(enabled, isTrue);
  });

  testWidgets('AppMotion(enabled: false) apaga el kit', (tester) async {
    late bool enabled;
    await tester.pumpWidget(
      AppMotion(
        enabled: false,
        child: probe((ctx) => enabled = AppMotion.enabledOf(ctx)),
      ),
    );
    expect(enabled, isFalse);
  });

  testWidgets('reduce-motion del SO apaga aunque la preferencia esté '
      'encendida (accesibilidad manda)', (tester) async {
    late bool enabled;
    await tester.pumpWidget(
      AppMotion(
        enabled: true,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                enabled = AppMotion.enabledOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    expect(enabled, isFalse);
  });

  testWidgets('durationOf devuelve la base encendido y Duration.zero apagado', (
    tester,
  ) async {
    late Duration on;
    await tester.pumpWidget(
      probe((ctx) => on = AppMotion.durationOf(ctx, AppTokens.durationBase)),
    );
    expect(on, AppTokens.durationBase);

    late Duration off;
    await tester.pumpWidget(
      AppMotion(
        enabled: false,
        child: probe(
          (ctx) => off = AppMotion.durationOf(ctx, AppTokens.durationBase),
        ),
      ),
    );
    expect(off, Duration.zero);
  });

  testWidgets('cambiar enabled reconstruye a los dependientes', (tester) async {
    final seen = <bool>[];
    Widget host(bool enabled) => AppMotion(
      enabled: enabled,
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            seen.add(AppMotion.enabledOf(context));
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pumpWidget(host(true));
    await tester.pumpWidget(host(false));

    expect(seen, <bool>[true, false]);
  });
}
