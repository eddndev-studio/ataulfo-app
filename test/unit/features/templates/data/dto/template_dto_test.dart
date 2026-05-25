import 'package:agentic/features/templates/data/dto/template_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> aiJson({
    bool enabled = false,
    String provider = 'GEMINI',
    String model = 'gemini-3.1-pro-preview',
    double temperature = 0.7,
    String thinkingLevel = 'LOW',
    String systemPrompt = '',
    int contextMessages = 20,
  }) => <String, dynamic>{
    'enabled': enabled,
    'provider': provider,
    'model': model,
    'temperature': temperature,
    'thinking_level': thinkingLevel,
    'system_prompt': systemPrompt,
    'context_messages': contextMessages,
  };

  group('AiConfigDto.fromJson', () {
    test('parsea el objeto canónico del campo ai', () {
      final c = AiConfigDto.fromJson(aiJson());

      expect(c.enabled, isFalse);
      expect(c.provider, 'GEMINI');
      expect(c.model, 'gemini-3.1-pro-preview');
      expect(c.temperature, 0.7);
      expect(c.thinkingLevel, 'LOW');
      expect(c.systemPrompt, '');
      expect(c.contextMessages, 20);
    });

    test('acepta temperature entera (decodificada como int por el JSON)', () {
      // dio puede entregar 1 en vez de 1.0 cuando el JSON no trae decimal;
      // el cliente lo normaliza para no romper contra valores válidos.
      final c = AiConfigDto.fromJson(aiJson()..['temperature'] = 1);
      expect(c.temperature, 1.0);
    });

    test('clave obligatoria ausente lanza FormatException', () {
      expect(
        () => AiConfigDto.fromJson(aiJson()..remove('provider')),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('TemplateResp.fromJson', () {
    Map<String, dynamic> tplJson({
      String id = 't1',
      String orgId = 'o1',
      String name = 'Soporte',
      int version = 1,
      Map<String, dynamic>? ai,
    }) => <String, dynamic>{
      'id': id,
      'org_id': orgId,
      'name': name,
      'version': version,
      'ai': ai ?? aiJson(),
    };

    test('parsea respuesta canónica de GET /templates con todos los campos', () {
      final r = TemplateResp.fromJson(tplJson(version: 3));

      expect(r.id, 't1');
      expect(r.orgId, 'o1');
      expect(r.name, 'Soporte');
      expect(r.version, 3);
      expect(r.ai.provider, 'GEMINI');
      expect(r.ai.model, 'gemini-3.1-pro-preview');
      expect(r.ai.thinkingLevel, 'LOW');
    });

    test('clave obligatoria ausente lanza FormatException', () {
      expect(
        () => TemplateResp.fromJson(tplJson()..remove('org_id')),
        throwsA(isA<FormatException>()),
      );
    });

    test('ai ausente lanza FormatException', () {
      expect(
        () => TemplateResp.fromJson(tplJson()..remove('ai')),
        throwsA(isA<FormatException>()),
      );
    });

    test('ai con shape inválido propaga FormatException', () {
      // AiConfigDto.fromJson rompe primero; TemplateResp debe dejar pasar la
      // excepción sin reempaquetarla.
      expect(
        () => TemplateResp.fromJson(tplJson(ai: aiJson()..remove('model'))),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
