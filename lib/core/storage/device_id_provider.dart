import 'package:uuid/uuid.dart';

import 'secure_kv_store.dart';

/// Provee un `device_id` UUID estable por instalación.
///
/// Generado al primer arranque y persistido en `SecureKvStore`. S02 RF#8 lo
/// usa como ancla de la familia de refresh; S17 lo necesita para registrar
/// el token FCM. Nacer estable hoy evita rotar familias el día que aterrice
/// push.
class DeviceIdProvider {
  DeviceIdProvider(this._kv, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const String _key = 'device.id.v1';

  final SecureKvStore _kv;
  final Uuid _uuid;

  Future<String> getOrCreate() async {
    final existing = await _kv.read(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final fresh = _uuid.v4();
    await _kv.write(_key, fresh);
    return fresh;
  }
}
