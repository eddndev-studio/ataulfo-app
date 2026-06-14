import 'package:ataulfo/features/templates/data/dto/template_dto.dart';
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

    test('parsea response_delay_seconds cuando viaja', () {
      final c = AiConfigDto.fromJson(aiJson()..['response_delay_seconds'] = 30);
      expect(c.responseDelaySeconds, 30);
    });

    test('response_delay_seconds ausente ⇒ 0 (clave aditiva, server viejo)', () {
      // A diferencia de las claves fundacionales (fail-loud), esta es aditiva:
      // un backend previo al campo no la manda y el cliente degrada a 0
      // (responder de inmediato) — mismo trato tolerante que `counts`.
      expect(AiConfigDto.fromJson(aiJson()).responseDelaySeconds, 0);
    });

    test('parsea silence_label_ids cuando viaja', () {
      final c = AiConfigDto.fromJson(
        aiJson()..['silence_label_ids'] = <dynamic>['l1', 'l2'],
      );
      expect(c.silenceLabelIds, <String>['l1', 'l2']);
    });

    test('silence_label_ids ausente ⇒ vacío (clave aditiva, omitempty)', () {
      // El backend la omite (omitempty) cuando no hay etiquetas de silencio;
      // el cliente degrada a lista vacía, igual que response_delay_seconds.
      expect(AiConfigDto.fromJson(aiJson()).silenceLabelIds, isEmpty);
    });

    test(
      'silence_label_ids filtra elementos no-string (defensa de contrato)',
      () {
        final c = AiConfigDto.fromJson(
          aiJson()..['silence_label_ids'] = <dynamic>['l1', 7, null, 'l2'],
        );
        expect(c.silenceLabelIds, <String>['l1', 'l2']);
      },
    );

    test('parsea disabled_tool_groups cuando viaja', () {
      final c = AiConfigDto.fromJson(
        aiJson()..['disabled_tool_groups'] = <dynamic>['flujos', 'documentos'],
      );
      expect(c.disabledToolGroups, <String>['flujos', 'documentos']);
    });

    test('disabled_tool_groups ausente ⇒ vacío (clave aditiva, omitempty)', () {
      expect(AiConfigDto.fromJson(aiJson()).disabledToolGroups, isEmpty);
    });

    test('disabled_tool_groups filtra elementos no-string', () {
      final c = AiConfigDto.fromJson(
        aiJson()..['disabled_tool_groups'] = <dynamic>['flujos', 9, null],
      );
      expect(c.disabledToolGroups, <String>['flujos']);
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

    test(
      'parsea respuesta canónica de GET /templates con todos los campos',
      () {
        final r = TemplateResp.fromJson(tplJson(version: 3));

        expect(r.id, 't1');
        expect(r.orgId, 'o1');
        expect(r.name, 'Soporte');
        expect(r.version, 3);
        expect(r.ai.provider, 'GEMINI');
        expect(r.ai.model, 'gemini-3.1-pro-preview');
        expect(r.ai.thinkingLevel, 'LOW');
      },
    );

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

    test('counts presente: parsea bots/flows/variables (listado)', () {
      final r = TemplateResp.fromJson(
        tplJson()
          ..['counts'] = <String, dynamic>{
            'bots': 3,
            'flows': 12,
            'variables': 4,
          },
      );
      expect(r.counts, isNotNull);
      expect(r.counts!.bots, 3);
      expect(r.counts!.flows, 12);
      expect(r.counts!.variables, 4);
    });

    test('counts ausente ⇒ null (respuesta de entidad única)', () {
      // GET /templates/:id, POST, PUT, duplicate no traen counts: el campo
      // es opcional y queda null sin romper el parseo.
      final r = TemplateResp.fromJson(tplJson());
      expect(r.counts, isNull);
    });

    test('counts presente pero con clave faltante lanza FormatException', () {
      expect(
        () => TemplateResp.fromJson(
          tplJson()..['counts'] = <String, dynamic>{'bots': 1, 'flows': 2},
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
