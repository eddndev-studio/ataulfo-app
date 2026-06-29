import 'package:ataulfo/features/org_ai_config/data/dto/org_ai_config_dto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _defaultsWire() => <String, dynamic>{
  'enabled': true,
  'provider': 'MINIMAX',
  'model': 'MiniMax-M3',
  'temperature': 0.9,
  'thinking_level': 'HIGH',
  'system_prompt': 'Eres soporte.',
  'context_messages': 15,
};

void main() {
  group('OrgAiConfigResp.fromJson', () {
    test('parsea hosts (mapa) + defaults (reusa AiConfigDto)', () {
      final dto = OrgAiConfigResp.fromJson(<String, dynamic>{
        'hosts': <String, dynamic>{'MiniMax-M3': 'FIREWORKS'},
        'defaults': _defaultsWire(),
      });
      expect(dto.hosts, <String, String>{'MiniMax-M3': 'FIREWORKS'});
      expect(dto.defaults.provider, 'MINIMAX');
      expect(dto.defaults.model, 'MiniMax-M3');
      expect(dto.defaults.thinkingLevel, 'HIGH');
    });

    test('hosts vacío es legítimo (org sin host fijado)', () {
      final dto = OrgAiConfigResp.fromJson(<String, dynamic>{
        'hosts': <String, dynamic>{},
        'defaults': _defaultsWire(),
      });
      expect(dto.hosts, isEmpty);
    });

    test('FormatException si falta hosts o defaults', () {
      expect(
        () => OrgAiConfigResp.fromJson(<String, dynamic>{
          'defaults': _defaultsWire(),
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => OrgAiConfigResp.fromJson(<String, dynamic>{
          'hosts': <String, dynamic>{},
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
