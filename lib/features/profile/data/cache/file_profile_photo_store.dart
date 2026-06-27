import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Foto de perfil cacheada en disco: los bytes (o `null` = marcador "sin foto")
/// más el instante en que se trajeron, derivado del mtime del archivo. El
/// consumidor usa [fetchedAt] para decidir frescura (TTL).
class CachedPhoto {
  const CachedPhoto({required this.bytes, required this.fetchedAt});

  /// Bytes de la foto; `null` cuando el archivo es el marcador de 0 bytes
  /// ("este chat no tiene foto") — distinto de un miss (archivo ausente).
  final Uint8List? bytes;

  /// Cuándo se escribió el archivo (su mtime). Es el `fetchedAt` para el TTL.
  final DateTime fetchedAt;
}

/// Store de bytes de foto de perfil respaldado por el sistema de archivos (un
/// archivo por clave bajo el cache dir de la app). A diferencia del cache de
/// media (refs inmutables, sin TTL), las fotos son **mutables** y
/// **account-scoped**: el orquestador revalida por TTL y purga todo en logout.
///
/// Se cachean los BYTES, nunca la URL: la `photoUrl` del perfil es una URL
/// efímera del CDN de Meta que caduca, así que guardarla sería inútil.
///
/// Un archivo de 0 bytes es un marcador negativo ("sin foto"): evita re-pegarle
/// al backend en cada visita por un contacto que de verdad no tiene foto. El
/// mtime del archivo es el `fetchedAt` que alimenta la decisión de TTL.
///
/// El nombre de archivo es `base64url(key)` sin padding: aplana la clave a un
/// único segmento filesystem-safe (sin riesgo de path traversal ni colisión).
/// [directoryProvider] permite inyectar un directorio temporal en tests sin
/// tocar el plugin nativo; en producción cae al cache dir de la app.
class FileProfilePhotoStore {
  FileProfilePhotoStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationCacheDirectory;

  final Future<Directory> Function() _directoryProvider;

  static const _subdir = 'profile_photos';

  // Sufijo único por escritura (proceso-local): dos writes concurrentes de la
  // misma clave no comparten el temporal y por tanto no chocan en el rename.
  static int _writeSeq = 0;

  Future<Directory> _dir() async {
    final base = await _directoryProvider();
    final dir = Directory('${base.path}/$_subdir');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  File _fileFor(Directory dir, String key) {
    final name = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
    return File('${dir.path}/$name');
  }

  Future<CachedPhoto?> read(String key) async {
    final file = _fileFor(await _dir(), key);
    if (!file.existsSync()) return null;
    final fetchedAt = file.statSync().modified;
    final bytes = await file.readAsBytes();
    // 0 bytes = marcador negativo "sin foto"; distinto del miss (archivo
    // ausente, que devuelve null arriba).
    if (bytes.isEmpty) return CachedPhoto(bytes: null, fetchedAt: fetchedAt);
    return CachedPhoto(bytes: Uint8List.fromList(bytes), fetchedAt: fetchedAt);
  }

  /// Persiste los [bytes]; `null` escribe el marcador de 0 bytes ("sin foto").
  Future<void> write(String key, Uint8List? bytes) async {
    final file = _fileFor(await _dir(), key);
    // Escritura atómica: escribir a un temporal y renombrar sobre el destino.
    // `rename` reemplaza atómicamente en el mismo filesystem (POSIX), así que un
    // read concurrente o un crash a media escritura nunca observa un archivo
    // truncado (que el TTL trataría como bytes válidos hasta caducar).
    final tmp = File('${file.path}.${_writeSeq++}.tmp');
    try {
      await tmp.writeAsBytes(bytes ?? Uint8List(0), flush: true);
      await tmp.rename(file.path);
    } catch (_) {
      if (tmp.existsSync()) await tmp.delete();
      rethrow;
    }
  }

  /// Purga todo el cache de fotos (logout). Tolera que el directorio no exista.
  Future<void> clear() async {
    try {
      final base = await _directoryProvider();
      final dir = Directory('${base.path}/$_subdir');
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (_) {
      // Best-effort: si el borrado falla, no hay nada que el caller pueda hacer.
    }
  }
}
