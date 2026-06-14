import 'package:ataulfo/features/bots/data/dto/bot_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> botJson() => <String, dynamic>{
    'id': 'b1',
    'org_id': 'o1',
    'template_id': 't1',
    'name': 'Soporte',
    'channel': 'WA_UNOFFICIAL',
    'version': 3,
    'paused': false,
    'ai_disabled': false,
  };

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

    test('parsea disabled_tool_groups (override de permisos del bot)', () {
      final resp = BotResp.fromJson(
        botJson()..['disabled_tool_groups'] = <dynamic>['flujos', 'notas'],
      );
      expect(resp.disabledToolGroups, <String>['flujos', 'notas']);
    });

    test('disabled_tool_groups ausente ⇒ vacío (clave aditiva)', () {
      expect(BotResp.fromJson(botJson()).disabledToolGroups, isEmpty);
    });

    test('disabled_tool_groups filtra elementos no-string', () {
      final resp = BotResp.fromJson(
        botJson()..['disabled_tool_groups'] = <dynamic>['flujos', 1, null],
      );
      expect(resp.disabledToolGroups, <String>['flujos']);
    });
  });

  group('BotUpdateReq.toJson — tristate de disabled_tool_groups', () {
    test('null ⇒ se omite la clave (no toca el override)', () {
      final json = const BotUpdateReq(version: 1).toJson();
      expect(json.containsKey('disabled_tool_groups'), isFalse);
    });

    test('[] ⇒ viaja como array vacío (limpiar el override)', () {
      final json = const BotUpdateReq(
        version: 1,
        disabledToolGroups: <String>[],
      ).toJson();
      expect(json['disabled_tool_groups'], <String>[]);
    });

    test('[..] ⇒ viaja la lista (set del override)', () {
      final json = const BotUpdateReq(
        version: 1,
        disabledToolGroups: <String>['flujos', 'documentos'],
      ).toJson();
      expect(json['disabled_tool_groups'], <String>['flujos', 'documentos']);
    });
  });
}
