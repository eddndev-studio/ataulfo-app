import 'package:ataulfo/core/db/app_db.dart';
import 'package:ataulfo/features/messages/data/mappers/message_row_mapper.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDb db;

  setUp(() => db = AppDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  // Inserta a través del mapper y recupera la fila tal como queda en la DB.
  Future<MessageRow> roundTrip(
    Message m, {
    String botId = 'b1',
    int syncedAtMs = 1,
  }) async {
    await db
        .into(db.messages)
        .insert(MessageRowMapper.toCompanion(botId, m, syncedAtMs: syncedAtMs));
    // Cada test crea su propia db en memoria con un único mensaje por externalId,
    // por lo que filtrar sólo por externalId es suficiente aquí.
    return (db.select(
      db.messages,
    )..where((t) => t.externalId.equals(m.externalId))).getSingle();
  }

  // ────────────────────────────────────────────────────────
  // OUTBOUND con status
  // ────────────────────────────────────────────────────────

  test(
    'OUTBOUND con status DELIVERED — round-trip entity→row→entity preserva todo',
    () async {
      const original = Message(
        externalId: 'ext-1',
        chatLid: 'chat-1',
        senderLid: 'sender-1',
        kind: MessageKind.dm,
        direction: MessageDirection.outbound,
        type: 'text',
        content: 'hola mundo',
        mediaRef: null,
        quotedId: null,
        timestampMs: 1700000000000,
        status: MessageStatus.delivered,
      );
      final row = await roundTrip(original, syncedAtMs: 42);
      expect(MessageRowMapper.rowToEntity(row), original);
      expect(row.status, MessageStatus.delivered.name);
      expect(row.direction, MessageDirection.outbound.name);
      expect(row.kind, MessageKind.dm.name);
      expect(row.syncedAtMs, 42);
    },
  );

  test('OUTBOUND con status READ round-trip preserva status', () async {
    const original = Message(
      externalId: 'ext-read',
      chatLid: 'chat-1',
      senderLid: 'sender-1',
      kind: MessageKind.dm,
      direction: MessageDirection.outbound,
      type: 'text',
      content: 'leído',
      mediaRef: null,
      quotedId: null,
      timestampMs: 1700000001000,
      status: MessageStatus.read,
    );
    final row = await roundTrip(original);
    expect(MessageRowMapper.rowToEntity(row), original);
    expect(row.status, MessageStatus.read.name);
  });

  // ────────────────────────────────────────────────────────
  // INBOUND con status nulo
  // ────────────────────────────────────────────────────────

  test(
    'INBOUND con status null — round-trip preserva nulo y todos los campos',
    () async {
      const original = Message(
        externalId: 'ext-2',
        chatLid: 'chat-1',
        senderLid: 'sender-2',
        kind: MessageKind.dm,
        direction: MessageDirection.inbound,
        type: 'text',
        content: 'respuesta del contacto',
        mediaRef: null,
        quotedId: null,
        timestampMs: 1700000002000,
        status: null,
      );
      final row = await roundTrip(original);
      expect(MessageRowMapper.rowToEntity(row), original);
      expect(row.status, isNull);
      expect(row.direction, MessageDirection.inbound.name);
    },
  );

  // ────────────────────────────────────────────────────────
  // mediaRef y quotedId presentes
  // ────────────────────────────────────────────────────────

  test('mediaRef y quotedId presentes round-trip correctamente', () async {
    const original = Message(
      externalId: 'ext-3',
      chatLid: 'chat-1',
      senderLid: 'sender-1',
      kind: MessageKind.group,
      direction: MessageDirection.inbound,
      type: 'image',
      content: '',
      mediaRef: 'ref/media/abc123',
      quotedId: 'ext-ref',
      timestampMs: 1700000003000,
      status: null,
    );
    final row = await roundTrip(original);
    expect(row.mediaRef, 'ref/media/abc123');
    expect(row.quotedId, 'ext-ref');
    expect(MessageRowMapper.rowToEntity(row), original);
  });

  // ────────────────────────────────────────────────────────
  // mediaRef y quotedId nulos
  // ────────────────────────────────────────────────────────

  test('mediaRef y quotedId nulos round-trip correctamente', () async {
    const original = Message(
      externalId: 'ext-4',
      chatLid: 'chat-1',
      senderLid: 'sender-1',
      kind: MessageKind.dm,
      direction: MessageDirection.outbound,
      type: 'text',
      content: 'sin media',
      mediaRef: null,
      quotedId: null,
      timestampMs: 1700000004000,
      status: MessageStatus.sent,
    );
    final row = await roundTrip(original);
    expect(row.mediaRef, isNull);
    expect(row.quotedId, isNull);
    expect(MessageRowMapper.rowToEntity(row), original);
  });

  // ────────────────────────────────────────────────────────
  // Enums por nombre
  // ────────────────────────────────────────────────────────

  test('kind GROUP se guarda y recupera por nombre del enum', () async {
    const original = Message(
      externalId: 'ext-5',
      chatLid: 'chat-group',
      senderLid: 'sender-1',
      kind: MessageKind.group,
      direction: MessageDirection.inbound,
      type: 'text',
      content: 'mensaje de grupo',
      mediaRef: null,
      quotedId: null,
      timestampMs: 1700000005000,
      status: null,
    );
    final row = await roundTrip(original);
    expect(row.kind, 'group');
    expect(MessageRowMapper.rowToEntity(row).kind, MessageKind.group);
  });

  test('direction inbound se guarda y recupera por nombre del enum', () async {
    const original = Message(
      externalId: 'ext-6',
      chatLid: 'chat-1',
      senderLid: 'sender-1',
      kind: MessageKind.dm,
      direction: MessageDirection.inbound,
      type: 'text',
      content: 'entrante',
      mediaRef: null,
      quotedId: null,
      timestampMs: 1700000006000,
      status: null,
    );
    final row = await roundTrip(original);
    expect(row.direction, 'inbound');
    expect(
      MessageRowMapper.rowToEntity(row).direction,
      MessageDirection.inbound,
    );
  });

  // ────────────────────────────────────────────────────────
  // mediaUrl NO se persiste
  // ────────────────────────────────────────────────────────

  test(
    'mediaUrl NO se persiste — la entidad reconstruida la tiene nula',
    () async {
      const msg = Message(
        externalId: 'ext-7',
        chatLid: 'chat-1',
        senderLid: 'sender-1',
        kind: MessageKind.dm,
        direction: MessageDirection.outbound,
        type: 'image',
        content: '',
        mediaRef: 'ref/img/xyz',
        quotedId: null,
        timestampMs: 1700000007000,
        status: MessageStatus.sent,
        mediaUrl: 'https://cdn.example.com/img/xyz.jpg',
      );
      final row = await roundTrip(msg);
      final entity = MessageRowMapper.rowToEntity(row);
      expect(entity.mediaUrl, isNull);
    },
  );
}
