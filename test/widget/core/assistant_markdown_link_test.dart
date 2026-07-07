import 'package:ataulfo/core/design/widgets/assistant_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('un link del markdown es tappable y entrega su URI', (
    tester,
  ) async {
    final launched = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantMarkdown(
            data: '[tu cotización](https://cdn.example/firmada)',
            onLinkTap: (uri) async {
              launched.add(uri);
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('tu cotización', findRichText: true));
    await tester.pump();
    expect(launched, <Uri>[Uri.parse('https://cdn.example/firmada')]);
  });

  testWidgets('un href malformado no truena ni lanza', (tester) async {
    final launched = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantMarkdown(
            data: '[roto](http://[::malformada)',
            onLinkTap: (uri) async {
              launched.add(uri);
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('roto', findRichText: true));
    await tester.pump();
    expect(launched, isEmpty);
  });
}
