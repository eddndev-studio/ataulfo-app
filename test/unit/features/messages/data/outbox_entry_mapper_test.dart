import 'package:ataulfo/core/db/app_db.dart';
import 'package:ataulfo/features/messages/data/mappers/outbox_entry_mapper.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDb db;

  setUp(() => db = AppDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<OutboxRow> insert(
    OutboxCompanion Function(OutboxCompanion base) build,
  ) async {
    final base = OutboxCompanion.insert(
      botId: 'b1',
      chatLid: 'c1',
      opType: 'send_message',
      clientToken: const Value('tok'),
      payload: '{"type":"text","content":"hola"}',
      createdAtMs: 1700,
      updatedAtMs: 1700,
    );
    final id = await db.into(db.outbox).insert(build(base));
    return (db.select(db.outbox)..where((o) => o.id.equals(id))).getSingle();
  }

  test('mapea una fila pending a OutboxEntry (no fallida)', () async {
    final row = await insert((b) => b);
    final entry = OutboxEntryMapper.fromRow(row)!;
    expect(entry.clientToken, 'tok');
    expect(entry.type, 'text');
    expect(entry.content, 'hola');
    expect(entry.mediaRef, isNull);
    expect(entry.isFailed, isFalse);
    expect(entry.createdAtMs, 1700);
  });

  test('una fila failed con media → isFailed + errorKind + mediaRef', () async {
    final row = await insert(
      (b) => b.copyWith(
        payload: const Value(
          '{"type":"image","content":"","mediaRef":"ref-9"}',
        ),
        state: const Value('failed'),
        errorKind: const Value('forbidden'),
      ),
    );
    final entry = OutboxEntryMapper.fromRow(row)!;
    expect(entry.type, 'image');
    expect(entry.mediaRef, 'ref-9');
    expect(entry.isFailed, isTrue);
    expect(entry.errorKind, 'forbidden');
  });

  test('respuesta → quotedId del payload', () async {
    final row = await insert(
      (b) => b.copyWith(
        payload: const Value(
          '{"type":"text","content":"respondo","quotedId":"orig-1"}',
        ),
      ),
    );
    final entry = OutboxEntryMapper.fromRow(row)!;
    expect(entry.quotedId, 'orig-1');
  });

  test('envío normal → quotedId null', () async {
    final row = await insert((b) => b);
    expect(OutboxEntryMapper.fromRow(row)!.quotedId, isNull);
  });

  test('payload corrupto → null (la fila se filtra)', () async {
    final row = await insert(
      (b) => b.copyWith(payload: const Value('no-json')),
    );
    expect(OutboxEntryMapper.fromRow(row), isNull);
  });

  test('sin clientToken → null', () async {
    final row = await insert((b) => b.copyWith(clientToken: const Value(null)));
    expect(OutboxEntryMapper.fromRow(row), isNull);
  });
}
