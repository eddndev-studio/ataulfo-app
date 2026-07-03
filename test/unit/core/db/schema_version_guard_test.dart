import 'package:ataulfo/core/db/app_db.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Huella canónica del esquema local: nombre de tabla + columnas
/// (nombre:tipo:nullable, ordenadas) + clave primaria. Determinista y sin
/// dependencias (FNV-1a). Si el esquema cambia, la huella cambia.
String _schemaFingerprint(AppDb db) {
  final parts = <String>[];
  final tables = db.allTables.toList()
    ..sort((a, b) => a.actualTableName.compareTo(b.actualTableName));
  for (final t in tables) {
    final cols =
        t.$columns.map((c) => '${c.name}:${c.type}:${c.$nullable}').toList()
          ..sort();
    final pk = t.$primaryKey.map((c) => c.name).toList()..sort();
    parts.add('${t.actualTableName}{${cols.join(',')}}pk[${pk.join(',')}]');
  }
  final canonical = parts.join(';');
  var hash = 0x811c9dc5;
  for (final r in canonical.runes) {
    hash = ((hash ^ r) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// Huella esperada POR versión de esquema. Al cambiar `tables.dart`:
///   1. sube `schemaVersion` en `app_db.dart`,
///   2. añade el paso de migración incremental en `onUpgrade` (conservando el
///      outbox),
///   3. registra aquí la nueva entrada `{nuevaVersión: nuevaHuella}`.
/// El guard de abajo falla si el esquema cambió sin pasar por estos tres pasos.
const Map<int, String> _schemaFingerprints = <int, String>{
  2: '9b5bbf50',
  3: '94e95575',
};

void main() {
  test('un cambio de esquema obliga a subir schemaVersion + migración', () {
    final db = AppDb.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final actual = _schemaFingerprint(db);
    final expected = _schemaFingerprints[db.schemaVersion];

    expect(
      expected,
      isNotNull,
      reason:
          'No hay huella registrada para schemaVersion ${db.schemaVersion}. '
          'Registra {${db.schemaVersion}: "$actual"} en _schemaFingerprints.',
    );
    expect(
      actual,
      expected,
      reason:
          'El esquema local cambió respecto a la huella de la versión '
          '${db.schemaVersion} (actual: "$actual"). Sube schemaVersion, añade '
          'el paso de migración incremental en onUpgrade (conservando el '
          'outbox) y registra la nueva huella en _schemaFingerprints.',
    );
  });
}
