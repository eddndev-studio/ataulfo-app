import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_notice_banner.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget banner) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: banner)));
  }

  BoxDecoration decoration(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(AppNoticeBanner),
            matching: find.byType(Container),
          )
          .first,
    );
    return container.decoration! as BoxDecoration;
  }

  testWidgets('info: ícono + mensaje, tint y borde primary', (tester) async {
    await pump(tester, const AppNoticeBanner.info(message: 'Sincronizando'));
    expect(find.text('Sincronizando'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    final d = decoration(tester);
    expect(d.color, AppTokens.primary.withValues(alpha: 0.10));
    expect(d.border?.top.color, AppTokens.primary);
  });

  testWidgets('warning: color warning en tint y borde', (tester) async {
    await pump(tester, const AppNoticeBanner.warning(message: 'Ojo'));
    final d = decoration(tester);
    expect(d.color, AppTokens.warning.withValues(alpha: 0.10));
    expect(d.border?.top.color, AppTokens.warning);
  });

  testWidgets('danger: color danger en tint y borde', (tester) async {
    await pump(tester, const AppNoticeBanner.danger(message: 'Falló'));
    final d = decoration(tester);
    expect(d.color, AppTokens.danger.withValues(alpha: 0.10));
    expect(d.border?.top.color, AppTokens.danger);
  });

  testWidgets('ícono override se respeta', (tester) async {
    await pump(
      tester,
      const AppNoticeBanner.info(message: 'x', icon: Icons.cloud_off_rounded),
    );
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsNothing);
  });

  testWidgets('acción trailing opcional se pinta cuando se pasa', (
    tester,
  ) async {
    await pump(
      tester,
      const AppNoticeBanner.warning(
        message: 'x',
        action: Icon(Icons.close, key: Key('act')),
      ),
    );
    expect(find.byKey(const Key('act')), findsOneWidget);
  });

  testWidgets('sin acción no monta trailing', (tester) async {
    await pump(tester, const AppNoticeBanner.info(message: 'x'));
    // Solo el ícono de leading: no hay un segundo ícono de acción.
    expect(find.byType(Icon), findsOneWidget);
  });
}
