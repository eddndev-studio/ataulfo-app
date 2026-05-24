import 'package:agentic/features/bots/data/datasources/bots_datasource.dart';
import 'package:agentic/features/bots/data/repositories/bots_repository_impl.dart';
import 'package:agentic/features/bots/domain/entities/bot.dart';
import 'package:agentic/features/bots/domain/failures/bots_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBotsDatasource extends Mock implements BotsDatasource {}

void main() {
  late _MockBotsDatasource ds;
  late BotsRepositoryImpl repo;

  setUp(() {
    ds = _MockBotsDatasource();
    repo = BotsRepositoryImpl(datasource: ds);
  });

  group('BotsRepositoryImpl.list', () {
    test('delega al datasource sin transformación adicional', () async {
      const bot = Bot(
        id: 'b1',
        orgId: 'o1',
        templateId: 't1',
        name: 'Soporte',
        channel: BotChannel.waUnofficial,
        identifier: '52155...',
        version: 3,
        paused: false,
        aiDisabled: false,
      );
      when(() => ds.list()).thenAnswer((_) async => const <Bot>[bot]);

      final result = await repo.list();

      expect(result, const <Bot>[bot]);
      verify(() => ds.list()).called(1);
    });

    test('propaga BotsFailure sin atraparla', () async {
      when(() => ds.list()).thenAnswer(
        (_) => Future<List<Bot>>.error(const BotsForbiddenFailure()),
      );

      await expectLater(repo.list(), throwsA(isA<BotsForbiddenFailure>()));
    });
  });

  group('BotsRepositoryImpl.byId', () {
    const bot = Bot(
      id: 'b1',
      orgId: 'o1',
      templateId: 't1',
      name: 'Soporte',
      channel: BotChannel.waUnofficial,
      identifier: '52155...',
      version: 3,
      paused: false,
      aiDisabled: false,
    );

    test('delega al datasource y devuelve el Bot tal cual', () async {
      when(() => ds.byId('b1')).thenAnswer((_) async => bot);

      final result = await repo.byId('b1');

      expect(result, bot);
      verify(() => ds.byId('b1')).called(1);
    });

    test('propaga BotsNotFoundFailure', () async {
      when(
        () => ds.byId('missing'),
      ).thenAnswer((_) => Future<Bot>.error(const BotsNotFoundFailure()));

      await expectLater(
        repo.byId('missing'),
        throwsA(isA<BotsNotFoundFailure>()),
      );
    });
  });
}
