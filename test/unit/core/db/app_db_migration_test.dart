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
      await v1.customStatement('PRAGMA user_version = 1');
      await v1.close();

      // Reabre en la versión actual → corre onUpgrade.
      final v2 = AppDb.forTesting(NativeDatabase(file));
      final outboxRows = await v2.select(v2.outbox).get();
      final convRows = await v2.select(v2.conversations).get();
      await v2.close();

      // El outbox (escrituras sin sincronizar) SOBREVIVE — invariante crítico.
      expect(outboxRows, hasLength(1));
      expect(outboxRows.first.payload, '{"text":"hola sin red"}');
      // Y el paso 1→2 no toca datos: la caché reconstruible también se conserva
      // (guarda el contrato "no-op preserva todo" contra un futuro paso que
      // recree conversations sin necesidad).
      expect(convRows, hasLength(1));
      expect(convRows.first.chatLid, '111@lid');
    } finally {
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
  });
}
