import 'package:ataulfo/core/db/app_db.dart';
import 'package:ataulfo/features/messages/data/datasources/messages_dao.dart';
import 'package:ataulfo/features/messages/data/datasources/messages_datasource.dart';
import 'package:ataulfo/features/messages/data/datasources/messages_events_datasource.dart';
import 'package:ataulfo/features/messages/data/datasources/outbox_dao.dart';
import 'package:ataulfo/features/messages/data/repositories/messages_repository_impl.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/domain/failures/messages_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements MessagesDatasource {}

class _MockEvents extends Mock implements MessagesEventsDatasource {}

/// `clearHistory` — orquestación del vaciado (S07 RF#10): el servidor es
/// autoritativo (DELETE primero); en éxito la verdad local se limpia
/// write-through (mensajes + cursor) y la proyección de la bandeja se vacía
/// vía el callback inyectado. En fallo del wire, lo local queda INTACTO: el
/// operador reintenta y el hilo jamás miente un vaciado que no ocurrió.
void main() {
  late AppDb db;
  late MessagesDao dao;
  late _MockDs ds;
  late List<(String, String)> projectionCleared;
  late MessagesRepositoryImpl repo;

  const m1 = Message(
    externalId: 'ext-1',
    chatLid: 'chat-1',
    senderLid: 'sender-1',
    kind: MessageKind.dm,
    direction: MessageDirection.inbound,
    type: 'text',
    content: 'hola',
    mediaRef: null,
    quotedId: null,
    timestampMs: 1000,
    status: null,
  );

  setUp(() {
    db = AppDb.forTesting(NativeDatabase.memory());
    dao = MessagesDao(db);
    ds = _MockDs();
    projectionCleared = [];
    repo = MessagesRepositoryImpl(
      datasource: ds,
      events: _MockEvents(),
      dao: dao,
      outbox: OutboxDao(db),
      requestSync: () {},
      clearConversationProjection: (botId, chatLid) async {
        projectionCleared.add((botId, chatLid));
      },
    );
  });
  tearDown(() => db.close());

  test(
    'éxito: DELETE al wire, hilo local vacío y bandeja proyectada',
    () async {
      when(() => ds.clearHistory('b1', 'chat-1')).thenAnswer((_) async {});
      await dao.upsertMessages('b1', [m1]);

      await repo.clearHistory('b1', 'chat-1');

      verify(() => ds.clearHistory('b1', 'chat-1')).called(1);
      expect(await dao.watchThread('b1', 'chat-1').first, isEmpty);
      expect(projectionCleared, [('b1', 'chat-1')]);
    },
  );

  test('fallo del wire: lo local queda intacto y la failure sube', () async {
    when(
      () => ds.clearHistory('b1', 'chat-1'),
    ).thenThrow(const MessagesServerFailure());
    await dao.upsertMessages('b1', [m1]);

    await expectLater(
      () => repo.clearHistory('b1', 'chat-1'),
      throwsA(isA<MessagesServerFailure>()),
    );
    expect(await dao.watchThread('b1', 'chat-1').first, hasLength(1));
    expect(projectionCleared, isEmpty);
  });

  test('sin callback de proyección: el vaciado no revienta', () async {
    final sinCallback = MessagesRepositoryImpl(
      datasource: ds,
      events: _MockEvents(),
      dao: dao,
      outbox: OutboxDao(db),
      requestSync: () {},
    );
    when(() => ds.clearHistory('b1', 'chat-1')).thenAnswer((_) async {});

    await sinCallback.clearHistory('b1', 'chat-1');
  });
}
