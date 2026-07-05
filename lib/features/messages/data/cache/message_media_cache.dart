import 'dart:typed_data';

import '../../../../core/media/media_byte_sink.dart';
import '../../../media/domain/repositories/media_byte_store.dart';

/// Descarga los bytes de una URL de media. Devuelve `null` si la descarga falla
/// (red caída / firma caducada / R2 sin objeto).
typedef MediaDownloader = Future<Uint8List?> Function(String url);

/// Cache de bytes de media de los mensajes, indexada por `mediaRef` (BARE,
/// opaco, estable e INMUTABLE: los bytes de un ref jamás cambian). L1 en memoria
/// sobre L2 en disco ([MediaByteStore]); **sin TTL** (a diferencia de las fotos
/// de perfil): una vez cacheados, los bytes sirven offline e ignorando la vida
/// de la `mediaUrl` firmada.
///
/// `bytesFor(mediaRef, mediaUrl)` resuelve: disco primero (offline / firma
/// expirada), si no descarga de `mediaUrl` UNA vez y persiste por ref. Deduplica
/// consultas en vuelo y cachea brevemente los fallos de descarga para no
/// martillar al CDN en cada repintado del hilo. Los bytes en disco NO se purgan
/// en logout (el ref embebe el tenant ⇒ sin colisión entre cuentas, inmutables);
/// [invalidate] sólo limpia la memoria.
class MessageMediaCache implements MediaByteSink {
  MessageMediaCache({
    required MediaByteStore store,
    required MediaDownloader download,
    Duration failureTtl = const Duration(seconds: 30),
    DateTime Function() now = DateTime.now,
  }) : _store = store,
       _download = download,
       _failureTtl = failureTtl,
       _now = now;

  final MediaByteStore _store;
  final MediaDownloader _download;
  final Duration _failureTtl;
  final DateTime Function() _now;

  final Map<String, Uint8List> _l1 = <String, Uint8List>{};
  final Map<String, DateTime> _failedAt = <String, DateTime>{};
  final Map<String, Future<Uint8List?>> _inflight =
      <String, Future<Uint8List?>>{};
  int _epoch = 0;

  /// Bytes de la media de `mediaRef`, o `null` si no se pudo resolver (offline
  /// sin caché / descarga fallida). Hit de L1 devuelve sincrónicamente. Si hay
  /// un fallo de descarga reciente, no reintenta (anti-martilleo). `mediaUrl`
  /// nulo = sólo sirve de caché (no hay de dónde bajar).
  Future<Uint8List?> bytesFor(String mediaRef, String? mediaUrl) {
    final cached = _l1[mediaRef];
    if (cached != null) return Future<Uint8List?>.value(cached);
    final failedAt = _failedAt[mediaRef];
    if (failedAt != null && _now().difference(failedAt) <= _failureTtl) {
      return Future<Uint8List?>.value(null);
    }
    final pending = _inflight[mediaRef];
    if (pending != null) return pending;
    final future = _resolve(mediaRef, mediaUrl);
    _inflight[mediaRef] = future;
    future.whenComplete(() => _inflight.remove(mediaRef));
    return future;
  }

  Future<Uint8List?> _resolve(String mediaRef, String? mediaUrl) async {
    final epoch = _epoch;
    Uint8List? disk;
    try {
      disk = await _store.read(mediaRef);
    } catch (_) {
      disk = null; // lectura corrupta/borrada: degrada a miss.
    }
    if (disk != null) {
      if (epoch == _epoch) _l1[mediaRef] = disk;
      return disk;
    }
    if (mediaUrl == null) {
      // Sin URL viva y sin caché (típico offline): no hay de dónde bajar. No se
      // cachea como fallo — re-resolver es sólo una lectura de disco, barata.
      return null;
    }
    final Uint8List? bytes;
    try {
      bytes = await _download(mediaUrl);
    } catch (_) {
      if (epoch == _epoch) _failedAt[mediaRef] = _now();
      return null;
    }
    if (bytes == null || bytes.isEmpty) {
      if (epoch == _epoch) _failedAt[mediaRef] = _now();
      return null;
    }
    if (epoch == _epoch) {
      // Persiste por ref (descargar una vez); un fallo de escritura no debe
      // tumbar la entrega de los bytes ya en mano.
      try {
        await _store.write(mediaRef, bytes);
      } catch (_) {}
      _l1[mediaRef] = bytes;
      _failedAt.remove(mediaRef);
    }
    return bytes;
  }

  /// Siembra la caché con bytes ya en mano (la copia local que el cliente
  /// produjo, p. ej. al GRABAR una nota de voz), bajo su `mediaRef` definitivo
  /// tras subir. Así la burbuja reproduce desde disco al instante —sin esperar
  /// el round-trip de la URL firmada— y la duración aparece de inmediato. Un
  /// fallo de escritura no es fatal: los bytes igual quedan en L1.
  @override
  Future<void> cache(String mediaRef, Uint8List bytes) async {
    try {
      await _store.write(mediaRef, bytes);
    } catch (_) {}
    _l1[mediaRef] = bytes;
    _failedAt.remove(mediaRef);
  }

  /// Limpia la memoria (logout). Los bytes en disco se conservan: el ref embebe
  /// el tenant (sin colisión entre cuentas) y son inmutables. Incrementa la
  /// generación para fencear una resolución en vuelo (no repuebla L1 tras logout).
  void invalidate() {
    _epoch++;
    _l1.clear();
    _failedAt.clear();
  }
}
