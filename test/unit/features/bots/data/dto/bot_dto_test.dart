import 'package:agentic/features/bots/data/dto/bot_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BotResp.fromJson', () {
    test('parsea respuesta canónica de GET /bots con todos los campos', () {
      final resp = BotResp.fromJson(<String, dynamic>{
        'id': 'b1',
        'org_id': 'o1',
        'template_id': 't1',
        'name': 'Soporte',
        'channel': 'WA_UNOFFICIAL',
        'identifier': '52155...',
        'version': 3,
        'paused': false,
        'ai_disabled': true,
      });

      expect(resp.id, 'b1');
      expect(resp.orgId, 'o1');
      expect(resp.templateId, 't1');
      expect(resp.name, 'Soporte');
      expect(resp.channel, 'WA_UNOFFICIAL');
      expect(resp.identifier, '52155...');
      expect(resp.version, 3);
      expect(resp.paused, isFalse);
      expect(resp.aiDisabled, isTrue);
    });

    test('identifier ausente queda nulo (backend lo omite con omitempty)', () {
      // El handler backend usa `omitempty` para `identifier` cuando el bot
      // todavía no fue pareado / etiquetado por el operador.
      final resp = BotResp.fromJson(<String, dynamic>{
        'id': 'b1',
        'org_id': 'o1',
        'template_id': 't1',
        'name': 'Soporte',
        'channel': 'WABA',
        'version': 1,
        'paused': true,
        'ai_disabled': false,
      });

      expect(resp.identifier, isNull);
      expect(resp.channel, 'WABA');
    });

    test('clave obligatoria ausente lanza FormatException', () {
      expect(
        () => BotResp.fromJson(<String, dynamic>{
          'id': 'b1',
          // falta org_id
          'template_id': 't1',
          'name': 'x',
          'channel': 'WABA',
          'version': 1,
          'paused': false,
          'ai_disabled': false,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
