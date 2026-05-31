import 'dart:typed_data';

import 'package:ataulfo/features/media/data/cache/caching_media_thumbnail_loader.dart';
import 'package:ataulfo/features/media/data/cache/media_byte_store.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:flutter_test/flutter_test.dart';

/// Store en memoria que cuenta escrituras: el test verifica QUÉ se persiste.
class _FakeStore implements MediaByteStore {
  final Map<String, Uint8List> _data = <String, Uint8List>{};
  final List<String> writes = <String>[];

  void seed(String ref, Uint8List bytes) => _data[ref] = bytes;

  @override
  Future<Uint8List?> read(String ref) async => _data[ref];

  @override
  Future<void> write(String ref, Uint8List bytes) async {
    writes.add(ref);
    _data[ref] = bytes;
  }
}

MediaAsset _asset({String? previewUrl}) => MediaAsset(
  ref: 'tenant/o/media/abc.png',
  previewUrl: previewUrl,
  filename: 'abc.png',
  contentType: 'image/png',
  size: 3,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  final cached = Uint8List.fromList(<int>[7, 7, 7]);
  final fetched = Uint8List.fromList(<int>[1, 2, 3]);

  test(
    'cache hit: sirve los bytes locales e IGNORA previewUrl (sin descarga)',
    () async {
      final store = _FakeStore()..seed('tenant/o/media/abc.png', cached);
      var downloads = 0;
      final loader = CachingMediaThumbnailLoader(
        store: store,
        download: (url) async {
          downloads++;
          return fetched;
        },
      );

      // previewUrl presente, pero el hit local manda: no debe tocar la red.
      final out = await loader.load(_asset(previewUrl: 'https://x/sig'));

      expect(out, cached);
      expect(downloads, 0);
      expect(store.writes, isEmpty);
    },
  );

  test(
    'miss + previewUrl: descarga, persiste por ref y devuelve los bytes',
    () async {
      final store = _FakeStore();
      final loader = CachingMediaThumbnailLoader(
        store: store,
        download: (url) async {
          expect(url, 'https://x/sig');
          return fetched;
        },
      );

      final out = await loader.load(_asset(previewUrl: 'https://x/sig'));

      expect(out, fetched);
      expect(store.writes, <String>['tenant/o/media/abc.png']);
      expect(await store.read('tenant/o/media/abc.png'), fetched);
    },
  );

  test('miss sin previewUrl: null y no intenta descargar', () async {
    final store = _FakeStore();
    var downloads = 0;
    final loader = CachingMediaThumbnailLoader(
      store: store,
      download: (url) async {
        downloads++;
        return fetched;
      },
    );

    expect(await loader.load(_asset(previewUrl: null)), isNull);
    expect(downloads, 0);
    expect(store.writes, isEmpty);
  });

  test(
    'miss + descarga falla (null): devuelve null y NO escribe basura',
    () async {
      final store = _FakeStore();
      final loader = CachingMediaThumbnailLoader(
        store: store,
        download: (url) async => null,
      );

      expect(await loader.load(_asset(previewUrl: 'https://x/sig')), isNull);
      expect(store.writes, isEmpty);
    },
  );
}
