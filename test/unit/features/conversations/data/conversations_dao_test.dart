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
