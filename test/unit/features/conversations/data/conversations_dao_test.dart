import 'package:ataulfo/core/db/app_db.dart';
import 'package:ataulfo/features/conversations/data/datasources/conversations_dao.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDb db;
  late ConversationsDao dao;

  setUp(() {
    db = AppDb.forTesting(NativeDatabase.memory());
    dao = ConversationsDao(db);
  });
  tearDown(() => db.close());

  ConversationsCompanion conv(
    String chatLid, {
    int? lastTs,
    String bot = 'b1',
  }) => ConversationsCompanion.insert(
    botId: bot,
    chatLid: chatLid,
    kind: 'dm',
    syncedAtMs: 0,
    lastMessageTimestampMs: Value.absentIfNull(lastTs),
  );

  test('watch ordena por reciente (DESC) con los nulos al final', () async {
    await dao.replaceForBot('b1', [
      conv('a', lastTs: 100),
      conv('b', lastTs: 300),
      conv('c'), // sin último mensaje
      conv('d', lastTs: 200),
    ]);
    final rows = await dao.watchForBot('b1').first;
    expect(rows.map((r) => r.chatLid).toList(), <String>['b', 'd', 'a', 'c']);
  });

  test('replaceForBot reemplaza el set anterior del bot', () async {
    await dao.replaceForBot('b1', [conv('a', lastTs: 1)]);
    await dao.replaceForBot('b1', [conv('x', lastTs: 5), conv('y', lastTs: 9)]);
    final rows = await dao.watchForBot('b1').first;
    expect(rows.map((r) => r.chatLid).toList(), <String>['y', 'x']);
  });

  test(
    'watch aísla por botId (mismo chatLid en otro bot no se cruza)',
    () async {
      await dao.replaceForBot('b1', [conv('a', lastTs: 1)]);
      await dao.replaceForBot('b2', [conv('a', lastTs: 1, bot: 'b2')]);
      final b1 = await dao.watchForBot('b1').first;
      expect(b1, hasLength(1));
      expect(b1.single.botId, 'b1');
    },
  );

  ConversationsCompanion convUnread(
    String chatLid, {
    required int unread,
    bool markedUnread = false,
    String bot = 'b1',
  }) => ConversationsCompanion.insert(
    botId: bot,
    chatLid: chatLid,
    kind: 'dm',
    syncedAtMs: 0,
    lastMessageTimestampMs: const Value(100),
    unreadCount: Value(unread),
    isMarkedUnread: Value(markedUnread),
  );

  test('clearUnread baja el badge de la fila (contador + marca)', () async {
    await dao.replaceForBot('b1', [
      convUnread('a', unread: 5, markedUnread: true),
    ]);
    await dao.clearUnread('b1', 'a');
    final row = (await dao.watchForBot('b1').first).single;
    expect(row.unreadCount, 0);
    expect(row.isMarkedUnread, isFalse);
  });

  test(
    'clearUnread no inserta filas ausentes (no hay badge que bajar)',
    () async {
      await dao.clearUnread('b1', 'ghost');
      expect(await dao.watchForBot('b1').first, isEmpty);
    },
  );

  test('clearUnread aísla por chat: otras filas quedan intactas', () async {
    await dao.replaceForBot('b1', [
      convUnread('a', unread: 5),
      convUnread('b', unread: 3),
    ]);
    await dao.clearUnread('b1', 'a');
    final rows = await dao.watchForBot('b1').first;
    final byId = {for (final r in rows) r.chatLid: r};
    expect(byId['a']!.unreadCount, 0);
    expect(byId['b']!.unreadCount, 3);
  });

  test(
    'un replace posterior del backend reconcilia (el snapshot es autoritativo)',
    () async {
      await dao.replaceForBot('b1', [convUnread('a', unread: 5)]);
      await dao.clearUnread('b1', 'a'); // optimista → 0
      expect((await dao.watchForBot('b1').first).single.unreadCount, 0);
      // El backend aún ve no-leídos (outbox sin drenar) y llega un pull:
      // el snapshot gana. Es el comportamiento correcto (eventual-consistente),
      // no un badge que resucita para siempre.
      await dao.replaceForBot('b1', [convUnread('a', unread: 5)]);
      expect((await dao.watchForBot('b1').first).single.unreadCount, 5);
    },
  );

  test('clearUnread hace re-emitir el watch (bandeja reactiva)', () async {
    await dao.replaceForBot('b1', [convUnread('a', unread: 5)]);
    final emissions = <int>[];
    final sub = dao
        .watchForBot('b1')
        .listen((rows) => emissions.add(rows.single.unreadCount));
    await Future<void>.delayed(Duration.zero);
    await dao.clearUnread('b1', 'a');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(emissions.first, 5);
    expect(emissions.last, 0);
  });

  test('watch re-emite tras un replace (reactivo)', () async {
    final emissions = <List<String>>[];
    final sub = dao
        .watchForBot('b1')
        .listen((rows) => emissions.add(rows.map((r) => r.chatLid).toList()));
    await Future<void>.delayed(Duration.zero); // emisión inicial (vacía)
    await dao.replaceForBot('b1', [conv('a', lastTs: 1)]);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(emissions.first, isEmpty);
    expect(emissions.last, <String>['a']);
  });
}
