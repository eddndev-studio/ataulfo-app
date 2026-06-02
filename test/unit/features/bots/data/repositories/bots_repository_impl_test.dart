import 'package:ataulfo/features/bots/data/datasources/bots_datasource.dart';
import 'package:ataulfo/features/bots/data/repositories/bots_repository_impl.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
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

  group('BotsRepositoryImpl.create', () {
    const created = Bot(
      id: 'b9',
      orgId: 'o1',
      templateId: 't1',
      name: 'Soporte',
      channel: BotChannel.waUnofficial,
      identifier: null,
      version: 0,
      paused: false,
      aiDisabled: false,
    );

    test('delega al datasource y devuelve el Bot creado', () async {
      when(
        () => ds.create(
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
        ),
      ).thenAnswer((_) async => created);

      final result = await repo.create(
        templateId: 't1',
        name: 'Soporte',
        channel: BotChannel.waUnofficial,
      );

      expect(result, created);
      verify(
        () => ds.create(
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
        ),
      ).called(1);
    });

    test('propaga BotsInvalidCreateFailure', () async {
      when(
        () => ds.create(
          templateId: 't1',
          name: '',
          channel: BotChannel.waUnofficial,
        ),
      ).thenAnswer((_) => Future<Bot>.error(const BotsInvalidCreateFailure()));

      await expectLater(
        repo.create(
          templateId: 't1',
          name: '',
          channel: BotChannel.waUnofficial,
        ),
        throwsA(isA<BotsInvalidCreateFailure>()),
      );
    });
  });

  group('BotsRepositoryImpl.update', () {
    const updated = Bot(
      id: 'b1',
      orgId: 'o1',
      templateId: 't1',
      name: 'Soporte+',
      channel: BotChannel.waUnofficial,
      identifier: '52155...',
      version: 4,
      paused: true,
      aiDisabled: false,
    );

    test('delega al datasource con los mismos argumentos', () async {
      when(
        () => ds.update(
          id: 'b1',
          version: 3,
          name: null,
          paused: true,
          aiDisabled: null,
          variableValues: null,
        ),
      ).thenAnswer((_) async => updated);

      final result = await repo.update(id: 'b1', version: 3, paused: true);

      expect(result, updated);
      verify(
        () => ds.update(
          id: 'b1',
          version: 3,
          name: null,
          paused: true,
          aiDisabled: null,
          variableValues: null,
        ),
      ).called(1);
    });

    test('propaga BotsConflictFailure sin atraparla', () async {
      when(
        () => ds.update(
          id: any(named: 'id'),
          version: any(named: 'version'),
          name: any(named: 'name'),
          paused: any(named: 'paused'),
          aiDisabled: any(named: 'aiDisabled'),
          variableValues: any(named: 'variableValues'),
        ),
      ).thenAnswer((_) => Future<Bot>.error(const BotsConflictFailure()));

      await expectLater(
        repo.update(id: 'b1', version: 1, name: 'x'),
        throwsA(isA<BotsConflictFailure>()),
      );
    });
  });

  group('BotsRepositoryImpl.clone', () {
    const clone = Bot(
      id: 'b2',
      orgId: 'o1',
      templateId: 't1',
      name: 'Soporte (copia)',
      channel: BotChannel.waUnofficial,
      identifier: null,
      version: 0,
      paused: false,
      aiDisabled: false,
    );

    test('delega al datasource y devuelve el clon (id nuevo)', () async {
      when(
        () => ds.clone(id: 'b1', name: 'Soporte (copia)'),
      ).thenAnswer((_) async => clone);

      final result = await repo.clone(id: 'b1', name: 'Soporte (copia)');

      expect(result, clone);
      verify(() => ds.clone(id: 'b1', name: 'Soporte (copia)')).called(1);
    });

    test('propaga BotsInvalidCreateFailure', () async {
      when(
        () => ds.clone(id: any(named: 'id'), name: any(named: 'name')),
      ).thenAnswer((_) => Future<Bot>.error(const BotsInvalidCreateFailure()));

      await expectLater(
        repo.clone(id: 'b1', name: ''),
        throwsA(isA<BotsInvalidCreateFailure>()),
      );
    });
  });
}
