import 'package:ataulfo/features/templates/data/dto/template_dto.dart';
import 'package:ataulfo/features/templates/data/mappers/templates_mapper.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // aiConfigToWire es la inversa de aiConfigDtoToEntity y la fuente única de la
  // serialización (templates `ai` + org `defaults`). Round-trip: serializar y
  // re-parsear devuelve el mismo value object — si un campo se cae de un lado,
  // este test lo caza.
  test('aiConfigToWire ↔ aiConfigDtoToEntity round-trip', () {
    const original = AIConfig(
      enabled: true,
      provider: AIProvider.minimax,
      model: 'MiniMax-M3',
      temperature: 1.1,
      thinkingLevel: ThinkingLevel.high,
      systemPrompt: 'Eres soporte.',
      contextMessages: 15,
      responseDelaySeconds: 30,
      silenceLabelIds: <String>['lbl-vip'],
      disabledToolGroups: <String>['flujos'],
    );
    final wire = TemplatesMapper.aiConfigToWire(original);
    final back = TemplatesMapper.aiConfigDtoToEntity(AiConfigDto.fromJson(wire));
    expect(back, original);
  });

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
    TemplateCountsDto? counts,
  }) => TemplateResp(
    id: id,
    orgId: orgId,
    name: name,
    version: version,
    ai: ai ?? aiDto(),
    counts: counts,
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

    test('traduce responseDelaySeconds (ventana de acumulación)', () {
      const dto = AiConfigDto(
        enabled: true,
        provider: 'GEMINI',
        model: 'gemini-3.1-pro-preview',
        temperature: 0.7,
        thinkingLevel: 'LOW',
        systemPrompt: '',
        contextMessages: 20,
        responseDelaySeconds: 45,
      );
      expect(TemplatesMapper.aiConfigDtoToEntity(dto).responseDelaySeconds, 45);
    });

    test('traduce silenceLabelIds (etiquetas de silencio)', () {
      const dto = AiConfigDto(
        enabled: true,
        provider: 'GEMINI',
        model: 'gemini-3.1-pro-preview',
        temperature: 0.7,
        thinkingLevel: 'LOW',
        systemPrompt: '',
        contextMessages: 20,
        silenceLabelIds: <String>['l1', 'l2'],
      );
      expect(TemplatesMapper.aiConfigDtoToEntity(dto).silenceLabelIds, <String>[
        'l1',
        'l2',
      ]);
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

    test('counts presente se mapea al value object de dominio', () {
      final t = TemplatesMapper.templateRespToEntity(
        tplResp(
          counts: const TemplateCountsDto(bots: 3, flows: 12, variables: 4),
        ),
      );
      expect(t.counts, isNotNull);
      expect(t.counts!.bots, 3);
      expect(t.counts!.flows, 12);
      expect(t.counts!.variables, 4);
    });

    test('counts ausente ⇒ Template.counts null', () {
      final t = TemplatesMapper.templateRespToEntity(tplResp());
      expect(t.counts, isNull);
    });
  });
}
