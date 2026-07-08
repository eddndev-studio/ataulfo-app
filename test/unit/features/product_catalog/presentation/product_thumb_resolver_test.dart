import 'dart:typed_data';

import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/repositories/media_byte_store.dart';
import 'package:ataulfo/features/media/domain/repositories/media_thumbnail_loader.dart';
import 'package:ataulfo/features/product_catalog/presentation/product_thumb_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

final _storeBytes = Uint8List.fromList(<int>[1]);
final _assetBytes = Uint8List.fromList(<int>[2]);

class _FakeStore implements MediaByteStore {
  bool broken = false;

  @override
  Future<Uint8List?> read(String ref) async {
    if (broken) throw StateError('disco roto');
    return ref == 'ref-cacheado' ? _storeBytes : null;
  }

  @override
  Future<void> write(String ref, Uint8List bytes) async {}
}

class _FakeLoader implements MediaThumbnailLoader {
  @override
  Future<Uint8List?> load(MediaAsset asset) async => _assetBytes;
}

MediaAsset _asset(String ref) => MediaAsset(
  ref: ref,
  previewUrl: null,
  filename: 'f.png',
  contentType: 'image/png',
  size: 1,
  createdAt: DateTime.utc(2026, 7, 1),
);

void main() {
  late _FakeStore store;
  late ProductThumbResolver resolver;

  setUp(() {
    store = _FakeStore();
    resolver = ProductThumbResolver(store: store, loader: _FakeLoader());
  });

  test('solo ref ⇒ lee del cache en disco', () async {
    expect(await resolver.load('ref-cacheado'), _storeBytes);
    expect(await resolver.load('ref-frio'), isNull);
  });

  test(
    'con el asset del picker (mismo ref) ⇒ usa el loader completo',
    () async {
      expect(
        await resolver.load('ref-frio', asset: _asset('ref-frio')),
        _assetBytes,
      );
    },
  );

  test('asset de OTRO ref ⇒ se ignora y se cae al cache', () async {
    expect(
      await resolver.load('ref-cacheado', asset: _asset('otro-ref')),
      _storeBytes,
    );
  });

  test('cualquier fallo ⇒ null (glifo, nunca error)', () async {
    store.broken = true;
    expect(await resolver.load('ref-cacheado'), isNull);
  });
}
