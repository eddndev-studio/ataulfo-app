import 'dart:io';

import 'package:ataulfo/core/db/app_db.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un upgrade de esquema conserva las escrituras del outbox', () async {
    // El outbox guarda escrituras hechas sin red que aún no se sincronizan; un
    // upgrade de esquema NO debe destruirlas (pérdida silenciosa de mensajes).
    // Las tablas reconstruibles (espejo del servidor) sí pueden recrearse: un
    // re-pull las repuebla.
    final dir = await Directory.systemTemp.createTemp('appdb_migration_test');
    final file = File('${dir.path}${Platform.pathSeparator}db.sqlite');
    try {
      // Estado "v1": el esquema actual marcado como versión 1, con una
      // escritura pendiente en el outbox y una conversación en caché.
      final v1 = AppDb.forTesting(NativeDatabase(file));
      await v1
          .into(v1.outbox)
          .insert(
            OutboxCompanion.insert(
              botId: 'bot-1',
              chatLid: '111@lid',
              opType: 'send_message',
              payload: '{"text":"hola sin red"}',
              createdAtMs: 1000,
              updatedAtMs: 1000,
            ),
          );
      await v1
          .into(v1.conversations)
          .insert(
            ConversationsCompanion.insert(
              botId: 'bot-1',
              chatLid: '111@lid',
              kind: 'user',
              syncedAtMs: 1000,
            ),
          );
      // Un mensaje del historial local pre-v4: debe sobrevivir al upgrade
      // con ai_run_id NULL (columna nueva aditiva), sin romper el hilo.
      await v1
          .into(v1.messages)
          .insert(
            MessagesCompanion.insert(
              botId: 'bot-1',
              externalId: 'wamid-1',
              chatLid: '111@lid',
              senderLid: 'op@lid',
              kind: 'chat',
              direction: 'out',
              type: 'text',
              content: 'hola viejo',
              timestampMs: 900,
              syncedAtMs: 1000,
            ),
          );
      // Fixture fiel al esquema VIEJO: las columnas que las migraciones
      // posteriores agregan se retiran para que onUpgrade las cree de
      // verdad (un createAll ya nace con el esquema actual).
      await v1.customStatement('ALTER TABLE messages DROP COLUMN edited_at_ms');
      await v1.customStatement(
        'ALTER TABLE messages DROP COLUMN revoked_at_ms',
      );
      await v1.customStatement('ALTER TABLE messages DROP COLUMN ai_run_id');
      await v1.customStatement('PRAGMA user_version = 1');
      await v1.close();

      // Reabre en la versión actual → corre onUpgrade.
      final v2 = AppDb.forTesting(NativeDatabase(file));
      final outboxRows = await v2.select(v2.outbox).get();
      final convRows = await v2.select(v2.conversations).get();
      final msgRows = await v2.select(v2.messages).get();
      await v2.close();

      // El outbox (escrituras sin sincronizar) SOBREVIVE — invariante crítico.
      expect(outboxRows, hasLength(1));
      expect(outboxRows.first.payload, '{"text":"hola sin red"}');
      // Y el paso 1→2 no toca datos: la caché reconstruible también se conserva
      // (guarda el contrato "no-op preserva todo" contra un futuro paso que
      // recree conversations sin necesidad).
      expect(convRows, hasLength(1));
      expect(convRows.first.chatLid, '111@lid');
      // El mensaje pre-v4 sobrevive con la columna nueva en NULL: si alguien
      // volviera ai_run_id non-nullable (o un mapper hiciera `aiRunId!`), este
      // es el test que debe caerse antes que el hilo en producción.
      expect(msgRows, hasLength(1));
      expect(msgRows.single.content, 'hola viejo');
      expect(msgRows.single.aiRunId, isNull);
    } finally {
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
  });
}
