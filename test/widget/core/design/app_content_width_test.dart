import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_content_width.dart';

void main() {
  const probe = SizedBox.shrink(key: Key('probe'));

  Widget host(Widget child) => MaterialApp(home: AppContentWidth(child: child));

  testWidgets(
    'en pantalla ancha (default 800) recorta el ancho del hijo a maxContentWidth',
    (tester) async {
      await tester.pumpWidget(host(probe));

      // La superficie por defecto es 800px de ancho: el hijo llena la caja
      // restringida, recortado al máximo de contenido (450), no a la ventana.
      final width = tester.getSize(find.byKey(const Key('probe'))).width;
      expect(width, AppTokens.maxContentWidth);
    },
  );

  testWidgets('en pantalla estrecha el contenido ocupa todo el ancho real', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(probe));

    // 360 < 450 ⇒ el max es transparente: el contenido llena el ancho real.
    final width = tester.getSize(find.byKey(const Key('probe'))).width;
    expect(width, 360);
  });
}
