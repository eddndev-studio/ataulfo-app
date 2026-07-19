import 'package:ataulfo/core/db/app_db.dart';
// `isNull` lo aporta el matcher de flutter_test; se oculta el homónimo de
// drift (expresión de columna) para evitar el choque de import.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDb db;

  setUp(() => db = AppDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insertConv(
    String botId,
    String chatLid, {
    String kind = 'dm',
    int syncedAtMs = 0,
    String? displayName,
    int unreadCount = 0,
    String? lastDirection,
    int? lastTimestampMs,
  }) {
    return db
        .into(db.conversations)
        .insert(
          ConversationsCompanion.insert(
            orgId: 'org-1',
            botId: botId,
            chatLid: chatLid,
            kind: kind,
            assistantId: 'assistant-$botId',
            assistantName: 'Asistente',
            channelName: 'Principal',
            channelType: 'WA_UNOFFICIAL',
            labelsJson: '[]',
            syncedAtMs: syncedAtMs,
            displayName: Value.absentIfNull(displayName),
            unreadCount: Value(unreadCount),
            lastMessageDirection: Value.absentIfNull(lastDirection),
            lastMessageTimestampMs: Value.absentIfNull(lastTimestampMs),
          ),
        );
  }

  Future<void> insertMsg(
    String botId,
    String externalId, {
    String chatLid = 'c1',
    String content = 'hola',
    int timestampMs = 0,
  }) {
    return db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            botId: botId,
            externalId: externalId,
            chatLid: chatLid,
            senderLid: 's1',
            kind: 'dm',
            direction: 'inbound',
            type: 'text',
            content: content,
            timestampMs: timestampMs,
            syncedAtMs: 0,
          ),
        );
  }

  test('abre, migra y deja las cuatro tablas consultables y vacías', () async {
    expect(await db.select(db.conversations).get(), isEmpty);
    expect(await db.select(db.messages).get(), isEmpty);
    expect(await db.select(db.syncCursors).get(), isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test(
    'conversación: roundtrip preserva campos y nulos; PK hace upsert',
    () async {
      await insertConv(
        'b1',
        'c1',
        displayName: 'Ana',
        unreadCount: 3,
        lastDirection: 'INBOUND',
        lastTimestampMs: 99,
      );

      final row = await (db.select(
        db.conversations,
      )..where((c) => c.chatLid.equals('c1'))).getSingle();
      expect(row.botId, 'b1');
      expect(row.displayName, 'Ana');
      expect(row.unreadCount, 3);
      expect(row.lastMessageDirection, 'INBOUND');
      expect(row.lastMessageTimestampMs, 99);
      // Defaults y nulos.
      expect(row.isArchived, isFalse);
      expect(row.isPinned, isFalse);
      expect(row.phone, isNull);
      expect(row.lastMessagePreview, isNull);

      // Misma (botId, chatLid) reemplaza, no duplica (I-S1).
      await db
          .into(db.conversations)
          .insertOnConflictUpdate(
            ConversationsCompanion.insert(
              orgId: 'org-1',
              botId: 'b1',
              chatLid: 'c1',
              kind: 'dm',
              assistantId: 'assistant-b1',
              assistantName: 'Asistente',
              channelName: 'Principal',
              channelType: 'WA_UNOFFICIAL',
              labelsJson: '[]',
              syncedAtMs: 200,
              displayName: const Value('Ana López'),
            ),
          );
      final after = await (db.select(
        db.conversations,
      )..where((c) => c.chatLid.equals('c1'))).get();
      expect(after, hasLength(1));
      expect(after.single.displayName, 'Ana López');
    },
  );

  test(
    'mensaje: I-M1 — misma externalId en bots distintos coexisten',
    () async {
      await insertMsg('b1', 'wamid-1');
      await insertMsg(
        'b2',
        'wamid-1',
      ); // mismo externalId, otro bot → no colisiona
      expect(await db.select(db.messages).get(), hasLength(2));

      // Mismo (bot, externalId) hace upsert (absorbe el eco del SSE).
      await db
          .into(db.messages)
          .insertOnConflictUpdate(
            MessagesCompanion.insert(
              botId: 'b1',
              externalId: 'wamid-1',
              chatLid: 'c1',
              senderLid: 's1',
              kind: 'dm',
              direction: 'inbound',
              type: 'text',
              content: 'editado',
              timestampMs: 0,
              syncedAtMs: 1,
            ),
          );
      final b1 = await (db.select(
        db.messages,
      )..where((m) => m.botId.equals('b1'))).get();
      expect(b1, hasLength(1));
      expect(b1.single.content, 'editado');
    },
  );

  test('clearAllData vacía todas las tablas', () async {
    await insertConv('b1', 'c1');
    await insertMsg('b1', 'e1');
    await db
        .into(db.syncCursors)
        .insert(SyncCursorsCompanion.insert(botId: 'b1', chatLid: 'c1'));
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            botId: 'b1',
            chatLid: 'c1',
            opType: 'send_message',
            payload: '{}',
            createdAtMs: 1,
            updatedAtMs: 1,
          ),
        );

    await db.clearAllData();

    expect(await db.select(db.conversations).get(), isEmpty);
    expect(await db.select(db.messages).get(), isEmpty);
    expect(await db.select(db.syncCursors).get(), isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test(
    'clearReadData vacía las tablas reconstruibles pero conserva el outbox',
    () async {
      await insertConv('b1', 'c1');
      await insertMsg('b1', 'e1');
      await db
          .into(db.syncCursors)
          .insert(SyncCursorsCompanion.insert(botId: 'b1', chatLid: 'c1'));
      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              botId: 'b1',
              chatLid: 'c1',
              opType: 'send_message',
              payload: '{"text":"sin red"}',
              createdAtMs: 1,
              updatedAtMs: 1,
            ),
          );

      await db.clearReadData();

      // Espejo reconstruible purgado (un re-pull lo repuebla en la nueva org).
      expect(await db.select(db.conversations).get(), isEmpty);
      expect(await db.select(db.messages).get(), isEmpty);
      expect(await db.select(db.syncCursors).get(), isEmpty);
      // El outbox (escrituras sin sincronizar) SOBREVIVE al cambio de org.
      expect(await db.select(db.outbox).get(), hasLength(1));
    },
  );

  test(
    'ámbito por botId: una consulta de un bot no ve filas de otro',
    () async {
      await insertConv('b1', 'c1');
      await insertConv('b2', 'c1'); // mismo chatLid, otro bot

      final b1 = await (db.select(
        db.conversations,
      )..where((c) => c.botId.equals('b1'))).get();
      expect(b1, hasLength(1));
      expect(b1.single.botId, 'b1');

      // El chatLid se repite entre bots sin colisión de PK.
      expect(await db.select(db.conversations).get(), hasLength(2));
    },
  );
}
