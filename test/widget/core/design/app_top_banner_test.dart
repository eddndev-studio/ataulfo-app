import 'package:ataulfo/core/design/widgets/app_top_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const inset = 24.0;

  /// Host con un inset de status bar simulado: el banner debe consumirlo y
  /// retirárselo al contenido de abajo mientras esté visible.
  Widget host({
    required bool visible,
    required ValueChanged<double> onChildTopPadding,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: inset)),
        child: AppTopBanner(
          visible: visible,
          bannerKey: const Key('t.banner'),
          content: const Text('aviso'),
          child: Builder(
            builder: (context) {
              onChildTopPadding(MediaQuery.paddingOf(context).top);
              return const Text('contenido');
            },
          ),
        ),
      ),
    );
  }

  testWidgets('visible: el contenido del aviso queda bajo el status bar', (
    tester,
  ) async {
    await tester.pumpWidget(host(visible: true, onChildTopPadding: (_) {}));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('t.banner')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('aviso')).dy,
      greaterThanOrEqualTo(inset),
      reason: 'la franja debe reservar el inset, no pintar debajo del reloj',
    );
  });

  testWidgets('visible: retira el inset superior al contenido de abajo', (
    tester,
  ) async {
    double? childTop;
    await tester.pumpWidget(
      host(visible: true, onChildTopPadding: (v) => childTop = v),
    );
    await tester.pumpAndSettle();

    expect(
      childTop,
      0,
      reason: 'la franja ya cubrió el status bar: sin esto habría doble inset',
    );
  });

  testWidgets('oculto: no pinta la franja y el contenido conserva su inset', (
    tester,
  ) async {
    double? childTop;
    await tester.pumpWidget(
      host(visible: false, onChildTopPadding: (v) => childTop = v),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('t.banner')), findsNothing);
    expect(find.text('aviso'), findsNothing);
    expect(childTop, inset);
    expect(find.text('contenido'), findsOneWidget);
  });

  testWidgets('al ocultarse la franja, el contenido recupera su inset', (
    tester,
  ) async {
    double? childTop;
    await tester.pumpWidget(
      host(visible: true, onChildTopPadding: (v) => childTop = v),
    );
    await tester.pumpAndSettle();
    expect(childTop, 0);

    await tester.pumpWidget(
      host(visible: false, onChildTopPadding: (v) => childTop = v),
    );
    await tester.pumpAndSettle();

    expect(find.text('aviso'), findsNothing);
    expect(childTop, inset);
  });
}
