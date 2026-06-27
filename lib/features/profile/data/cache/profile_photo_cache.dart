import 'dart:typed_data';

import '../../domain/repositories/profile_repository.dart';
import 'file_profile_photo_store.dart';

/// Descarga los bytes de una URL de foto. Devuelve `null` si la descarga falla
/// (red caída / URL caducada) — distinto de "sin foto", que se modela aguas
/// arriba con una `photoUrl` nula.
typedef PhotoDownloader = Future<Uint8List?> Function(String url);

class _Entry {
  _Entry(this.bytes, this.fetchedAt);

  /// `null` = marcador "sin foto" cacheado en memoria (espejo del marcador de
  /// disco): evita re-resolver un contacto sin foto en cada repintado.
  final Uint8List? bytes;
  final DateTime fetchedAt;
}

/// Cache de fotos de perfil de dos niveles: L1 en memoria sobre L2 en disco
/// ([FileProfilePhotoStore]). Resuelve la foto de un chat con revalidación por
/// TTL, deduplica consultas en vuelo, cachea brevemente los fallos para no
/// martillar al backend en cada repintado de la lista, y degrada con gracia
/// sirviendo la copia rancia de disco cuando el backend o la descarga fallan.
///
/// Las fotos son mutables y account-scoped: se cachean los BYTES (la `photoUrl`
/// del perfil es una URL efímera del CDN de Meta que caduca) y se purga todo en
/// logout vía [invalidate]. La clave es `'$botId $chatLid'`.
class ProfilePhotoCache {
  ProfilePhotoCache({
    required ProfileRepository profileRepo,
    required PhotoDownloader download,
    FileProfilePhotoStore? store,
    Duration ttl = const Duration(hours: 12),
    Duration failureTtl = const Duration(seconds: 30),
    DateTime Function() now = DateTime.now,
  }) : _repo = profileRepo,
       _download = download,
       _store = store ?? FileProfilePhotoStore(),
       _ttl = ttl,
       _failureTtl = failureTtl,
       _now = now;

  final ProfileRepository _repo;
  final PhotoDownloader _download;
  final FileProfilePhotoStore _store;
  final Duration _ttl;
  final Duration _failureTtl;
  final DateTime Function() _now;

  final Map<String, _Entry> _l1 = <String, _Entry>{};
  // Marca de tiempo del último fallo por clave: caché negativa de corta vida
  // para que el scroll no dispare una fetch+descarga por cada repintado de una
  // foto que falla.
  final Map<String, DateTime> _failedAt = <String, DateTime>{};
  // Consultas en vuelo: varias peticiones por la misma clave comparten una
  // única resolución (una sola fetch + descarga), no N en paralelo.
  final Map<String, Future<Uint8List?>> _inflight =
      <String, Future<Uint8List?>>{};
  // Generación: [invalidate] la incrementa para que una resolución en vuelo que
  // termina DESPUÉS del logout no repueble disco/L1 con la cuenta anterior.
  int _epoch = 0;

  /// Bytes de la foto del chat, o `null` (sin foto / no resuelta). Hit de L1
  /// fresco devuelve sincrónicamente; si no, resuelve (con dedup) contra disco
  /// y backend, salvo que haya un fallo reciente cacheado.
  Future<Uint8List?> photoFor(String botId, String chatLid) {
    final key = '$botId $chatLid';
    final entry = _l1[key];
    if (entry != null && _fresh(entry.fetchedAt)) {
      return Future<Uint8List?>.value(entry.bytes);
    }
    final failedAt = _failedAt[key];
    if (failedAt != null && _now().difference(failedAt) <= _failureTtl) {
      // Fallo reciente: sirve lo rancio que haya sin re-resolver (anti-martilleo).
      return Future<Uint8List?>.value(entry?.bytes);
    }
    final pending = _inflight[key];
    if (pending != null) return pending;
    final future = _resolve(key, botId, chatLid);
    _inflight[key] = future;
    future.whenComplete(() => _inflight.remove(key));
    return future;
  }

  bool _fresh(DateTime fetchedAt) => _now().difference(fetchedAt) <= _ttl;

  Future<Uint8List?> _resolve(String key, String botId, String chatLid) async {
    final epoch = _epoch;
    CachedPhoto? disk;
    try {
      disk = await _store.read(key);
    } catch (_) {
      disk = null; // lectura de disco corrupta / borrada: degrada a miss.
    }
    if (disk != null && _fresh(disk.fetchedAt)) {
      _write(key, epoch, disk.bytes, disk.fetchedAt);
      return disk.bytes;
    }
    try {
      final profile = await _repo.fetch(botId, chatLid);
      final url = profile.photoUrl;
      if (url == null) {
        // Sin foto: persiste el marcador negativo para no re-consultar.
        if (epoch == _epoch) {
          await _store.write(key, null);
          _write(key, epoch, null, _now());
          _failedAt.remove(key);
        }
        return null;
      }
      final bytes = await _download(url);
      if (bytes == null || bytes.isEmpty) {
        // Descarga fallida o cuerpo vacío (NO es "sin foto"): no persistas un
        // marcador. Sirve disco rancio si lo hay; cachea el fallo brevemente.
        return _serveStale(key, disk, epoch);
      }
      if (epoch == _epoch) {
        await _store.write(key, bytes);
        _write(key, epoch, bytes, _now());
        _failedAt.remove(key);
      }
      return bytes;
    } catch (_) {
      // fetch o descarga lanzó: degrada a la copia rancia de disco si existe.
      return _serveStale(key, disk, epoch);
    }
  }

  /// Escribe en L1 sólo si la generación no cambió (no repuebla tras un logout).
  void _write(String key, int epoch, Uint8List? bytes, DateTime fetchedAt) {
    if (epoch == _epoch) _l1[key] = _Entry(bytes, fetchedAt);
  }

  Uint8List? _serveStale(String key, CachedPhoto? disk, int epoch) {
    // Tras un logout (generación distinta) no se repuebla L1 ni la caché de
    // fallos; sólo se devuelve lo que ya había en disco al consumidor en vuelo.
    if (epoch != _epoch) return disk?.bytes;
    _failedAt[key] = _now();
    if (disk != null) {
      _l1[key] = _Entry(disk.bytes, disk.fetchedAt);
      return disk.bytes;
    }
    return null;
  }

  /// Purga L1, la caché de fallos y el disco (logout): ninguna foto de la cuenta
  /// anterior debe sobrevivir. Incrementa la generación para fencear las
  /// resoluciones en vuelo.
  Future<void> invalidate() async {
    _epoch++;
    _l1.clear();
    _failedAt.clear();
    await _store.clear();
  }
}
