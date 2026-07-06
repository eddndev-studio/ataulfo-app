import 'dart:typed_data';

import 'package:ataulfo/features/media/application/device_gallery_resolver.dart';
import 'package:ataulfo/features/media/data/repositories/noop_device_gallery.dart';
import 'package:ataulfo/features/media/domain/repositories/device_gallery_port.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carrete de prueba: marca que la factory de Android se invocó sin construir
/// el plugin real (que necesitaría canales de plataforma).
class _StubGallery implements DeviceGalleryPort {
  @override
  Future<DeviceGalleryAvailability> availability() async =>
      DeviceGalleryAvailability.available;

  @override
  Future<void> openSettings() async {}
  @override
  Future<List<DeviceMediaAsset>> recentMedia({
    int limit = 60,
    int page = 0,
  }) async => const <DeviceMediaAsset>[];
  @override
  Future<Uint8List?> thumbnailFor(DeviceMediaAsset asset, {int size = 256}) =>
      Future<Uint8List?>.value();
  @override
  Future<PickedMedia?> bytesFor(DeviceMediaAsset asset) async => null;
}

void main() {
  test('en Android construye el carrete real (factory inyectada)', () {
    var built = 0;
    final resolver = DeviceGalleryResolver(
      isAndroid: true,
      androidGallery: () {
        built++;
        return _StubGallery();
      },
    );

    final g = resolver.resolve();

    expect(built, 1);
    expect(g, isA<_StubGallery>());
  });

  test('fuera de Android usa el Noop (sin construir el real)', () {
    var built = 0;
    final resolver = DeviceGalleryResolver(
      isAndroid: false,
      androidGallery: () {
        built++;
        return _StubGallery();
      },
    );

    final g = resolver.resolve();

    expect(built, 0);
    expect(g, isA<NoopDeviceGallery>());
  });
}
