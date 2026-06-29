import 'dart:typed_data';

import 'package:ataulfo/features/media/domain/repositories/media_byte_store.dart';
import 'package:ataulfo/features/messages/data/cache/message_media_cache.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStore implements MediaByteStore {
  final Map<String, Uint8List> data = <String, Uint8List>{};
  int writes = 0;

  @override
  Future<Uint8List?> read(String ref) async => data[ref];

  @override
  Future<void> write(String ref, Uint8List bytes) async {
    writes++;
    data[ref] = bytes;
  }
}

void main() {
  late _FakeStore store;
  late DateTime now;
  final bytes = Uint8List.fromList(<int>[1, 2, 3]);

  setUp(() {
    store = _FakeStore();
    now = DateTime.fromMillisecondsSinceEpoch(1000);
  });

  MessageMediaCache make({required MediaDownloader download}) =>
      MessageMediaCache(store: store, download: download, now: () => now);

  test(
    'hit en disco devuelve los bytes e ignora mediaUrl (sin descargar)',
    () async {
      store.data['ref'] = bytes;
      var downloads = 0;
      final cache = make(
        download: (_) async {
          downloads++;
          return null;
        },
      );

      expect(await cache.bytesFor('ref', 'https://cdn/x.jpg'), bytes);
      expect(downloads, 0);
    },
  );

  test(
    'cache() siembra disco + L1: bytesFor los sirve sin descargar',
    () async {
      var downloads = 0;
      final cache = make(
        download: (_) async {
          downloads++;
          return null;
        },
      );

      await cache.cache('ref', bytes);

      expect(store.data['ref'], bytes, reason: 'persistido en disco');
      expect(await cache.bytesFor('ref', 'https://cdn/x.ogg'), bytes);
      expect(downloads, 0, reason: 'servido de caché, jamás baja');
    },
  );

  test('miss + mediaUrl: descarga, persiste por ref y cachea en L1', () async {
    var downloads = 0;
    final cache = make(
      download: (_) async {
        downloads++;
        return bytes;
      },
    );

    expect(await cache.bytesFor('ref', 'https://cdn/x.jpg'), bytes);
    expect(await cache.bytesFor('ref', 'https://cdn/x.jpg'), bytes); // L1
    expect(downloads, 1, reason: 'descarga una sola vez');
    expect(store.writes, 1);
    expect(store.data['ref'], bytes);
  });

  test(
    'miss sin mediaUrl → null (no cachea fallo: re-resolver es barato)',
    () async {
      var downloads = 0;
      final cache = make(
        download: (_) async {
          downloads++;
          return bytes;
        },
      );

      expect(await cache.bytesFor('ref', null), isNull);
      expect(downloads, 0);
    },
  );

  test(
    'descarga fallida (null) → null y cachea el fallo (no re-descarga)',
    () async {
      var downloads = 0;
      final cache = make(
        download: (_) async {
          downloads++;
          return null;
        },
      );

      expect(await cache.bytesFor('ref', 'https://cdn/x.jpg'), isNull);
      expect(await cache.bytesFor('ref', 'https://cdn/x.jpg'), isNull);
      expect(downloads, 1, reason: 'el fallo reciente no se reintenta');
    },
  );

  test('descarga vacía → null y cachea el fallo', () async {
    var downloads = 0;
    final cache = make(
      download: (_) async {
        downloads++;
        return Uint8List(0);
      },
    );

    expect(await cache.bytesFor('ref', 'https://cdn/x.jpg'), isNull);
    expect(await cache.bytesFor('ref', 'https://cdn/x.jpg'), isNull);
    expect(downloads, 1);
    expect(store.writes, 0, reason: 'una descarga vacía no se persiste');
  });

  test('tras failureTtl re-descarga', () async {
    var downloads = 0;
    Uint8List? result;
    final cache = make(
      download: (_) async {
        downloads++;
        return result;
      },
    );

    expect(await cache.bytesFor('ref', 'https://cdn/x.jpg'), isNull); // falla
    now = now.add(const Duration(seconds: 31));
    result = bytes; // ya hay bytes
    expect(await cache.bytesFor('ref', 'https://cdn/x.jpg'), bytes);
    expect(downloads, 2);
  });

  test('llamadas concurrentes deduplican (una sola descarga)', () async {
    var downloads = 0;
    final cache = make(
      download: (_) async {
        downloads++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return bytes;
      },
    );

    final results = await Future.wait([
      cache.bytesFor('ref', 'https://cdn/x.jpg'),
      cache.bytesFor('ref', 'https://cdn/x.jpg'),
    ]);

    expect(results, [bytes, bytes]);
    expect(downloads, 1);
  });

  test('invalidate limpia la caché de fallos (vuelve a intentar)', () async {
    var downloads = 0;
    Uint8List? result;
    final cache = make(
      download: (_) async {
        downloads++;
        return result;
      },
    );

    expect(await cache.bytesFor('ref', 'https://cdn/x.jpg'), isNull); // falla
    cache.invalidate();
    result = bytes;
    expect(await cache.bytesFor('ref', 'https://cdn/x.jpg'), bytes);
    expect(downloads, 2);
  });
}
