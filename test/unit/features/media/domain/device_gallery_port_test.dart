import 'dart:typed_data';

import 'package:ataulfo/features/media/domain/repositories/device_gallery_port.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake mínimo del carrete: valida que el contrato sea implementable sin
/// plataforma (fotos en memoria, bytes bajo demanda).
class _FakeGallery implements DeviceGalleryPort {
  _FakeGallery(this.assets, this.bytesById);

  final List<DeviceMediaAsset> assets;
  final Map<String, Uint8List> bytesById;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<List<DeviceMediaAsset>> recentMedia({int limit = 60}) async =>
      assets.take(limit).toList(growable: false);

  @override
  Future<Uint8List?> thumbnailFor(DeviceMediaAsset asset, {int size = 256}) =>
      Future<Uint8List?>.value(bytesById[asset.id]);

  @override
  Future<PickedMedia?> bytesFor(DeviceMediaAsset asset) async {
    final bytes = bytesById[asset.id];
    if (bytes == null) return null;
    return PickedMedia(bytes: bytes, filename: asset.filename);
  }
}

void main() {
  group('DeviceMediaAsset', () {
    test('modela un asset del carrete sin bytes (id + nombre + tipo)', () {
      const photo = DeviceMediaAsset(id: 'a1', filename: 'IMG_001.jpg');
      const video = DeviceMediaAsset(
        id: 'v1',
        filename: 'VID_002.mp4',
        isVideo: true,
        durationMs: 12500,
      );

      expect(photo.id, 'a1');
      expect(photo.filename, 'IMG_001.jpg');
      expect(photo.isVideo, isFalse);
      expect(photo.durationMs, isNull);
      expect(video.isVideo, isTrue);
      expect(video.durationMs, 12500);
    });
  });

  group('DeviceGalleryPort (contrato)', () {
    late _FakeGallery gallery;

    setUp(() {
      gallery = _FakeGallery(
        const <DeviceMediaAsset>[
          DeviceMediaAsset(id: 'a1', filename: 'uno.jpg'),
          DeviceMediaAsset(id: 'a2', filename: 'dos.mp4', isVideo: true),
          DeviceMediaAsset(id: 'a3', filename: 'tres.png'),
        ],
        <String, Uint8List>{
          'a1': Uint8List.fromList(<int>[1, 2]),
          'a2': Uint8List.fromList(<int>[3]),
        },
      );
    });

    test('recentMedia respeta el límite pedido', () async {
      final two = await gallery.recentMedia(limit: 2);
      expect(two, hasLength(2));
      expect(two.first.id, 'a1');
    });

    test(
      'bytesFor materializa el asset como PickedMedia (bytes+nombre)',
      () async {
        final picked = await gallery.bytesFor(
          const DeviceMediaAsset(id: 'a1', filename: 'uno.jpg'),
        );
        expect(picked, isNotNull);
        expect(picked!.filename, 'uno.jpg');
        expect(picked.bytes, Uint8List.fromList(<int>[1, 2]));
      },
    );

    test(
      'bytesFor devuelve null cuando el asset ya no está disponible',
      () async {
        final picked = await gallery.bytesFor(
          const DeviceMediaAsset(id: 'zombie', filename: 'no.jpg'),
        );
        expect(picked, isNull);
      },
    );

    test('thumbnailFor devuelve null cuando no hay miniatura', () async {
      final thumb = await gallery.thumbnailFor(
        const DeviceMediaAsset(id: 'a3', filename: 'tres.png'),
      );
      expect(thumb, isNull);
    });
  });
}
