import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_detail_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppDesignTheme.dark(),
      home: Scaffold(body: child),
    ),
  );

  testWidgets('centraliza identidad, navegación, edición y metadatos', (
    tester,
  ) async {
    var backs = 0;
    var edits = 0;
    await pump(
      tester,
      AppDetailHeader(
        title: 'Soporte',
        subtitle: 'WhatsApp Business',
        backKey: const Key('detail.back'),
        onBack: () => backs++,
        editKey: const Key('detail.edit'),
        editTooltip: 'Editar Canal',
        onEdit: () => edits++,
        metadata: const <Widget>[Text('v4')],
      ),
    );

    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('WhatsApp Business'), findsOneWidget);
    expect(find.text('v4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail.back')));
    await tester.tap(find.byKey(const Key('detail.edit')));
    expect(backs, 1);
    expect(edits, 1);
  });

  testWidgets('usa el radio y la escala tipográfica canónicos', (tester) async {
    await pump(
      tester,
      AppDetailHeader(
        title: 'Ventas',
        subtitle: 'Gemini · modelo',
        onBack: () {},
      ),
    );

    final clip = tester.widget<ClipRRect>(
      find.descendant(
        of: find.byType(AppDetailHeader),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(
      clip.borderRadius,
      const BorderRadius.only(
        bottomLeft: Radius.circular(AppTokens.radiusHeader),
        bottomRight: Radius.circular(AppTokens.radiusHeader),
      ),
    );
    final theme = AppDesignTheme.dark().textTheme;
    final subtitle = tester.widget<Text>(find.text('Gemini · modelo'));
    expect(subtitle.style?.fontSize, theme.bodyLarge?.fontSize);
  });

  testWidgets('sin edición no monta el lápiz', (tester) async {
    await pump(
      tester,
      AppDetailHeader(title: 'Ventas', subtitle: 'WhatsApp', onBack: () {}),
    );

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });
}
