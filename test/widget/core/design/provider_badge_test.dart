import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/provider_badge.dart';
import 'package:agentic/features/templates/domain/entities/template.dart';

void main() {
  Future<void> pump(WidgetTester tester, AIProvider p) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(body: ProviderBadge(provider: p)),
      ),
    );
  }

  group('ProviderBadge — label humanizado por enum', () {
    testWidgets('openai → "OpenAI"', (tester) async {
      await pump(tester, AIProvider.openai);
      expect(find.text('OpenAI'), findsOneWidget);
    });

    testWidgets('gemini → "Gemini"', (tester) async {
      await pump(tester, AIProvider.gemini);
      expect(find.text('Gemini'), findsOneWidget);
    });

    testWidgets('minimax → "MiniMax"', (tester) async {
      await pump(tester, AIProvider.minimax);
      expect(find.text('MiniMax'), findsOneWidget);
    });

    testWidgets('deepseek → "DeepSeek"', (tester) async {
      await pump(tester, AIProvider.deepseek);
      expect(find.text('DeepSeek'), findsOneWidget);
    });
  });

  group('ProviderBadge — estilo', () {
    testWidgets('label DM Sans bodyMedium con color text2', (tester) async {
      await pump(tester, AIProvider.gemini);

      final style = tester.widget<Text>(find.text('Gemini')).style;
      // El widget consume el textTheme del theme y aplica text2 al final;
      // chequeamos las tres propiedades que sustentan la decisión visual.
      expect(style?.fontFamily, AppTokens.fontSans);
      expect(style?.fontSize, AppTokens.bodyMSize);
      expect(style?.color, AppTokens.text2);
    });
  });
}
