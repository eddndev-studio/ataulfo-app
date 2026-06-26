import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/assistant_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(String data) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: AssistantMarkdown(data: data)),
  );

  // Localiza el primer RichText cuyo texto plano contiene [needle]. El render
  // de markdown produce RichText (no Text), así que se inspecciona el árbol de
  // spans en vez de find.text.
  RichText richContaining(WidgetTester tester, String needle) {
    return tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((rt) => rt.text.toPlainText().contains(needle));
  }

  bool anySpanHasWeight(InlineSpan root, FontWeight weight) {
    var found = false;
    root.visitChildren((span) {
      if (span is TextSpan &&
          (span.text?.isNotEmpty ?? false) &&
          span.style?.fontWeight == weight) {
        found = true;
      }
      return true;
    });
    return found;
  }

  testWidgets('usa MarkdownBody (no Text plano) para el contenido', (
    tester,
  ) async {
    await tester.pumpWidget(host('hola'));
    expect(find.byType(MarkdownBody), findsOneWidget);
  });

  testWidgets('negrita: **negrita** rinde la palabra en w700', (tester) async {
    await tester.pumpWidget(host('**negrita**'));
    final rt = richContaining(tester, 'negrita');
    expect(anySpanHasWeight(rt.text, FontWeight.w700), isTrue);
  });

  testWidgets('código inline: `code` rinde el texto', (tester) async {
    await tester.pumpWidget(host('`code`'));
    expect(richContaining(tester, 'code').text.toPlainText(), contains('code'));
  });

  testWidgets('lista: - a / - b rinde ambos ítems', (tester) async {
    await tester.pumpWidget(host('- a\n- b'));
    final all = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((rt) => rt.text.toPlainText())
        .join('\n');
    expect(all, contains('a'));
    expect(all, contains('b'));
  });

  testWidgets('heading: # Hola no excede la tipografía de título', (
    tester,
  ) async {
    await tester.pumpWidget(host('# Hola'));
    final rt = richContaining(tester, 'Hola');
    final size = rt.text.style?.fontSize;
    expect(size, isNotNull);
    // Acotado al token de título grande; nunca el tamaño gigante por defecto.
    expect(size! <= AppTokens.titleLSize, isTrue);
  });

  testWidgets('texto plano intacto con color de cuerpo del design system', (
    tester,
  ) async {
    await tester.pumpWidget(host('hola mundo'));
    final rt = richContaining(tester, 'hola mundo');
    expect(rt.text.toPlainText(), contains('hola mundo'));
    expect(rt.text.style?.color, AppTokens.text1);
  });
}
