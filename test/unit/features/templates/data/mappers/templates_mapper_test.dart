import 'package:agentic/features/templates/data/dto/template_dto.dart';
import 'package:agentic/features/templates/data/mappers/templates_mapper.dart';
import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AiConfigDto aiDto({
    bool enabled = false,
    String provider = 'GEMINI',
    String model = 'gemini-3.1-pro-preview',
    double temperature = 0.7,
    String thinkingLevel = 'LOW',
    String systemPrompt = '',
    int contextMessages = 20,
  }) => AiConfigDto(
    enabled: enabled,
    provider: provider,
    model: model,
    temperature: temperature,
    thinkingLevel: thinkingLevel,
    systemPrompt: systemPrompt,
    contextMessages: contextMessages,
  );

  TemplateResp tplResp({
    String id = 't1',
    String orgId = 'o1',
    String name = 'Soporte',
    int version = 1,
    AiConfigDto? ai,
  }) => TemplateResp(
    id: id,
    orgId: orgId,
    name: name,
    version: version,
    ai: ai ?? aiDto(),
  );

  group('TemplatesMapper.aiConfigDtoToEntity', () {
    test('traduce campos uno a uno usando fromWire fail-loud', () {
      final c = TemplatesMapper.aiConfigDtoToEntity(
        aiDto(
          enabled: true,
          provider: 'OPENAI',
          model: 'gpt-5',
          temperature: 1.0,
          thinkingLevel: 'HIGH',
          systemPrompt: 'eres un agente',
          contextMessages: 10,
        ),
      );

      expect(c.enabled, isTrue);
      expect(c.provider, AIProvider.openai);
      expect(c.model, 'gpt-5');
      expect(c.temperature, 1.0);
      expect(c.thinkingLevel, ThinkingLevel.high);
      expect(c.systemPrompt, 'eres un agente');
      expect(c.contextMessages, 10);
    });

    test('proveedor desconocido propaga ArgumentError (fail-loud)', () {
      expect(
        () => TemplatesMapper.aiConfigDtoToEntity(aiDto(provider: 'ANTHROPIC')),
        throwsArgumentError,
      );
    });

    test('thinking level desconocido propaga ArgumentError (fail-loud)', () {
      expect(
        () => TemplatesMapper.aiConfigDtoToEntity(aiDto(thinkingLevel: 'NONE')),
        throwsArgumentError,
      );
    });
  });

  group('TemplatesMapper.templateRespToEntity', () {
    test('traduce un TemplateResp completo a Template', () {
      final t = TemplatesMapper.templateRespToEntity(tplResp(version: 5));

      expect(t.id, 't1');
      expect(t.orgId, 'o1');
      expect(t.name, 'Soporte');
      expect(t.version, 5);
      expect(t.ai.provider, AIProvider.gemini);
      expect(t.ai.thinkingLevel, ThinkingLevel.low);
    });
  });
}
