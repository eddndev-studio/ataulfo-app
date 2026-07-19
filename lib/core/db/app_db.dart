import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_db.g.dart';

/// Base de datos local del cliente: única fuente de verdad de la UI del núcleo
/// conversacional. La red la alimenta (pull HTTP + push SSE escriben aquí) y un
/// outbox encola las escrituras hechas sin conexión. La UI observa la DB; nunca
/// pega HTTP directo.
@DriftDatabase(tables: [Conversations, Messages, SyncCursors, Outbox])
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  /// Inyecta un ejecutor a medida — en pruebas, `NativeDatabase.memory()`.
  AppDb.forTesting(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Migraciones incrementales y NO destructivas. El outbox guarda
      // escrituras hechas sin red que aún no se sincronizan: JAMÁS se dropea o
      // se perderían mensajes/marcas/reacciones del usuario. Las tablas
      // reconstruibles (espejo de la verdad del servidor) sí pueden recrearse
      // en el paso de migración cuando su esquema cambie —un re-pull las
      // repuebla—, pero nunca con un drop global. Cada versión nueva añade su
      // propio bloque aditivo `if (from < N) { ... }`; drift sólo invoca
      // onUpgrade cuando `schemaVersion` sube, así que cada cambio en
      // `tables.dart` debe subir la versión Y traer su paso de migración (un
      // guard de CI lo verifica), o un dispositivo viejo revienta en runtime.
      //
      // v1→v2: corte de la recreación destructiva a migración incremental. El
      // esquema no cambió, así que este paso no toca datos: conserva la caché y
      // el outbox intactos.
      //
      // v2→v3: messages gana los marcadores de corrección (editado/revocado),
      // nullable ⇒ ADD COLUMN aditivo, sin tocar datos ni outbox.
      if (from < 3) {
        await m.addColumn(messages, messages.editedAtMs);
        await m.addColumn(messages, messages.revokedAtMs);
      }
      // v3→v4: messages gana aiRunId (la corrida de IA que produjo el
      // OUTBOUND — La Traza F5). Nullable ⇒ ADD COLUMN aditivo; las filas
      // previas quedan NULL ('' en dominio: sin badge, honesto).
      if (from < 4) {
        await m.addColumn(messages, messages.aiRunId);
      }
      // v4→v5: la Bandeja pasa de snapshot per-Bot a proyección org-scoped.
      // La identidad `(bot_id, chat_lid)` ya existía; sólo añadimos procedencia,
      // atención y etiquetas internas. Los defaults del ALTER conservan las
      // filas antiguas hasta que el siguiente pull autoritativo las reemplace.
      if (from < 5) {
        await customStatement(
          'ALTER TABLE conversations ADD COLUMN needs_attention '
          'INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE conversations ADD COLUMN assistant_id '
          'TEXT NOT NULL DEFAULT \'\'',
        );
        await customStatement(
          'ALTER TABLE conversations ADD COLUMN assistant_name '
          'TEXT NOT NULL DEFAULT \'\'',
        );
        await customStatement(
          'ALTER TABLE conversations ADD COLUMN channel_name '
          'TEXT NOT NULL DEFAULT \'\'',
        );
        await customStatement(
          'ALTER TABLE conversations ADD COLUMN channel_type '
          'TEXT NOT NULL DEFAULT \'\'',
        );
        await customStatement(
          'ALTER TABLE conversations ADD COLUMN channel_identifier TEXT',
        );
        await customStatement(
          'ALTER TABLE conversations ADD COLUMN labels_json '
          'TEXT NOT NULL DEFAULT \'[]\'',
        );
      }
      // v5→v6: namespace explícito del espejo de Bandeja. Las filas antiguas
      // quedan sin dueño (`''`) y no se revelan; el siguiente pull de la org
      // activa las repuebla. Es preferible perder una caché reconstruible tras
      // el upgrade a atribuirla a un tenant que no podemos inferir localmente.
      if (from < 6) {
        await customStatement(
          'ALTER TABLE conversations ADD COLUMN org_id '
          'TEXT NOT NULL DEFAULT \'\'',
        );
        await customStatement('DROP INDEX IF EXISTS idx_conversations_inbox');
        await customStatement(
          'CREATE INDEX idx_conversations_inbox ON conversations '
          '(org_id, is_pinned, last_message_timestamp_ms, bot_id, chat_lid)',
        );
      }
    },
  );

  /// Borra toda la verdad local. Se invoca al cerrar sesión: ninguna fila de la
  /// cuenta anterior debe persistir. Transaccional para no dejar tablas a medio
  /// vaciar si algo falla a mitad.
  Future<void> clearAllData() {
    return transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }

  /// Borra sólo la verdad local RECONSTRUIBLE (conversaciones, mensajes y
  /// cursores), conservando el outbox. Se invoca al cambiar de organización
  /// activa: el espejo del servidor de la org anterior no debe verse en la
  /// nueva (un re-pull lo repuebla), pero las escrituras hechas sin red que aún
  /// no se sincronizan NO se pierden. Transaccional.
  Future<void> clearReadData() {
    return transaction(() async {
      await delete(conversations).go();
      await delete(messages).go();
      await delete(syncCursors).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}agentic_app.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
