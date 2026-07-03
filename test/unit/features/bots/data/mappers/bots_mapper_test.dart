import 'package:ataulfo/features/bots/data/dto/bot_dto.dart';
import 'package:ataulfo/features/bots/data/mappers/bots_mapper.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BotsMapper.botRespToEntity', () {
    test('traduce wire WA_UNOFFICIAL → BotChannel.waUnofficial', () {
      const resp = BotResp(
        id: 'b1',
        orgId: 'o1',
        templateId: 't1',
        name: 'Soporte',
        channel: 'WA_UNOFFICIAL',
        identifier: '52155...',
        version: 3,
        paused: false,
        aiDisabled: true,
      );

      final bot = BotsMapper.botRespToEntity(resp);

      expect(
        bot,
        const Bot(
          id: 'b1',
          orgId: 'o1',
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
          identifier: '52155...',
          version: 3,
          paused: false,
          aiDisabled: true,
        ),
      );
    });

    test('traduce wire WABA → BotChannel.waba con identifier nulo', () {
      const resp = BotResp(
        id: 'b2',
        orgId: 'o1',
        templateId: 't2',
        name: 'Cobranza',
        channel: 'WABA',
        identifier: null,
        version: 1,
        paused: true,
        aiDisabled: false,
      );

      final bot = BotsMapper.botRespToEntity(resp);

      expect(bot.channel, BotChannel.waba);
      expect(bot.identifier, isNull);
      expect(bot.paused, isTrue);
    });

    test('traslada los gates de grupos del DTO a la entidad', () {
      const resp = BotResp(
        id: 'b1',
        orgId: 'o1',
        templateId: 't1',
        name: 'Soporte',
        channel: 'WA_UNOFFICIAL',
        identifier: null,
        version: 1,
        paused: false,
        aiDisabled: false,
        groupChatsAiDisabled: true,
        groupChatsFlowsDisabled: true,
      );

      final bot = BotsMapper.botRespToEntity(resp);

      expect(bot.groupChatsAiDisabled, isTrue);
      expect(bot.groupChatsFlowsDisabled, isTrue);
    });

    test('canal desconocido propaga ArgumentError (fail-loud del enum)', () {
      // El mapper no atrapa: una respuesta con canal nuevo no debe
      // degradarse silenciosa — el bug debe verse en boot, no en la UI.
      const resp = BotResp(
        id: 'b3',
        orgId: 'o1',
        templateId: 't3',
        name: 'x',
        channel: 'TELEGRAM',
        identifier: null,
        version: 1,
        paused: false,
        aiDisabled: false,
      );

      expect(() => BotsMapper.botRespToEntity(resp), throwsArgumentError);
    });
  });
}
