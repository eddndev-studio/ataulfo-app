import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacén clave-valor cifrado (Keystore en Android). Puerto para que el
/// dominio (y los tests) no dependan de `flutter_secure_storage` directo.
///
/// Las claves son strings opacas controladas por cada caller; este puerto
/// no impone esquema. Las implementaciones devuelven `null` en miss de
/// `read` y son idempotentes en `delete`.
abstract interface class SecureKvStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Implementación real contra `flutter_secure_storage`. Encryption-at-rest
/// la provee el plugin (Android Keystore / iOS Keychain — Android-first).
class FlutterSecureKvStore implements SecureKvStore {
  FlutterSecureKvStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
