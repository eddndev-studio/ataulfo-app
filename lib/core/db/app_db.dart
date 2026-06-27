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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // El almacén local es un espejo reconstruible de la verdad del servidor:
      // mientras el esquema evoluciona se recrea (drop + createAll) en vez de
      // migrar. OJO: drift sólo invoca onUpgrade cuando `schemaVersion` cambia,
      // así que CADA cambio en `tables.dart` debe subir `schemaVersion`; si no,
      // un dispositivo con la DB vieja conserva el esquema previo y revienta en
      // runtime ("no such column"). Sustituir por migraciones incrementales
      // antes de que el outbox guarde escrituras sin sincronizar que deban
      // sobrevivir a un upgrade.
      for (final table in allTables.toList().reversed) {
        await m.deleteTable(table.actualTableName);
      }
      await m.createAll();
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}agentic_app.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
