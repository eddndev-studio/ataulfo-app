import 'package:ataulfo/features/org_ai_config/domain/entities/org_ai_config.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:flutter_test/flutter_test.dart';

const _defaults = AIConfig(
  enabled: false,
  provider: AIProvider.gemini,
  model: 'gemini-3.1-pro-preview',
  temperature: 0.7,
  thinkingLevel: ThinkingLevel.low,
  systemPrompt: '',
  contextMessages: 20,
);

void main() {
  group('OrgAiConfig', () {
    test('hostFor devuelve el host fijado o null', () {
      const cfg = OrgAiConfig(
        hosts: <String, String>{'MiniMax-M3': 'FIREWORKS'},
        defaults: _defaults,
      );
      expect(cfg.hostFor('MiniMax-M3'), 'FIREWORKS');
      expect(cfg.hostFor('gpt-5.5'), isNull);
    });

    test('withHost fija sin tocar el resto', () {
      const cfg = OrgAiConfig(hosts: <String, String>{}, defaults: _defaults);
      final next = cfg.withHost('MiniMax-M3', 'FIREWORKS');
      expect(next.hostFor('MiniMax-M3'), 'FIREWORKS');
      expect(cfg.hostFor('MiniMax-M3'), isNull, reason: 'inmutable');
    });

    test('clearHost quita el pin (no-op si no estaba)', () {
      const cfg = OrgAiConfig(
        hosts: <String, String>{'MiniMax-M3': 'FIREWORKS'},
        defaults: _defaults,
      );
      expect(cfg.clearHost('MiniMax-M3').hosts, isEmpty);
      expect(identical(cfg.clearHost('ausente'), cfg), isTrue);
    });

    test('withDefaults reemplaza defaults conservando hosts', () {
      const cfg = OrgAiConfig(
        hosts: <String, String>{'MiniMax-M3': 'FIREWORKS'},
        defaults: _defaults,
      );
      final nd = _defaults.copyWith(provider: AIProvider.openai, model: 'gpt-5.5');
      final next = cfg.withDefaults(nd);
      expect(next.defaults.provider, AIProvider.openai);
      expect(next.hostFor('MiniMax-M3'), 'FIREWORKS');
    });

    test('igualdad: hosts (orden-independiente) + defaults', () {
      const a = OrgAiConfig(
        hosts: <String, String>{'MiniMax-M3': 'FIREWORKS', 'deepseek-v4-pro': 'DEEPSEEK'},
        defaults: _defaults,
      );
      const b = OrgAiConfig(
        hosts: <String, String>{'deepseek-v4-pro': 'DEEPSEEK', 'MiniMax-M3': 'FIREWORKS'},
        defaults: _defaults,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.withHost('MiniMax-M3', 'MINIMAX'), isFalse);
    });
  });
}
