import 'package:ataulfo/core/db/app_db.dart';
import 'package:ataulfo/features/conversations/data/datasources/conversations_dao.dart';
import 'package:ataulfo/features/conversations/data/datasources/conversations_datasource.dart';
import 'package:ataulfo/features/conversations/data/repositories/conversations_repository_impl.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/domain/failures/conversations_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements ConversationsDatasource {}

/// DAO cuya escritura local falla con un error NO tipado (simula un error crudo
/// de drift, p. ej. "database is locked").
class _ThrowingDao implements ConversationsDao {
  @override
  Stream<List<ConversationRow>> watchForBot(String botId) =>
      const Stream<List<ConversationRow>>.empty();

  @override
  Future<void> replaceForBot(String botId, List<ConversationsCompanion> rows) =>
      throw StateError('boom');

  @override
  Future<void> clearUnread(String botId, String chatLid) =>
      throw StateError('boom');
}

const _c1 = Conversation(
  chatLid: 'lid-1',
  kind: ConversationKind.dm,
  phone: null,
  isArchived: false,
  isPinned: false,
  isMarkedUnread: false,
  mutedUntil: null,
);
const _c2 = Conversation(
  chatLid: 'lid-2',
  kind: ConversationKind.dm,
  phone: null,
  isArchived: false,
  isPinned: false,
  isMarkedUnread: false,
  mutedUntil: null,
);

void main() {
  late AppDb db;
  late _MockDs ds;
  late ConversationsRepositoryImpl repo;

  setUp(() {
    db = AppDb.forTesting(NativeDatabase.memory());
    ds = _MockDs();
    repo = ConversationsRepositoryImpl(
      datasource: ds,
      dao: ConversationsDao(db),
      now: () => DateTime.fromMillisecondsSinceEpoch(99),
    );
  });
  tearDown(() => db.close());

  test('refresh escribe el snapshot HTTP y el watch lo emite', () async {
    when(() => ds.listForBot('b1')).thenAnswer((_) async => const [_c1]);
    await repo.refresh('b1');
    expect(await repo.watchForBot('b1').first, const [_c1]);
  });

  test('refresh fallido por red NO toca la caché previa', () async {
    when(() => ds.listForBot('b1')).thenAnswer((_) async => const [_c1]);
    await repo.refresh('b1'); // siembra
    when(
      () => ds.listForBot('b1'),
    ).thenThrow(const ConversationsNetworkFailure());

    await expectLater(
      repo.refresh('b1'),
      throwsA(isA<ConversationsNetworkFailure>()),
    );
    expect(await repo.watchForBot('b1').first, const [_c1]); // intacta
  });

  test('refresh reemplaza el set anterior por el snapshot fresco', () async {
    when(() => ds.listForBot('b1')).thenAnswer((_) async => const [_c1]);
    await repo.refresh('b1');
    when(() => ds.listForBot('b1')).thenAnswer((_) async => const [_c2]);
    await repo.refresh('b1');
    expect(await repo.watchForBot('b1').first, const [_c2]);
  });

  test(
    'error NO tipado de la escritura local → UnknownConversationsFailure',
    () async {
      final r = ConversationsRepositoryImpl(
        datasource: ds,
        dao: _ThrowingDao(),
      );
      when(() => ds.listForBot('b1')).thenAnswer((_) async => const [_c1]);
      await expectLater(
        r.refresh('b1'),
        throwsA(isA<UnknownConversationsFailure>()),
      );
    },
  );
}
