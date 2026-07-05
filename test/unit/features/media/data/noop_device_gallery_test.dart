import 'package:ataulfo/features/media/data/repositories/noop_device_gallery.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/features/media/domain/repositories/device_gallery_port.dart';

void main() {
  const gallery = NoopDeviceGallery();
  const asset = DeviceMediaAsset(id: 'x', filename: 'x.jpg');

  test('isSupported responde false (la UI no ofrece Galería)', () async {
    expect(await gallery.isSupported(), isFalse);
  });

  test('recentMedia responde lista vacía sin lanzar', () async {
    expect(await gallery.recentMedia(limit: 10), isEmpty);
  });

  test('thumbnailFor responde null sin lanzar', () async {
    expect(await gallery.thumbnailFor(asset, size: 256), isNull);
  });

  test(
    'bytesFor responde null sin lanzar (como una lectura fallida)',
    () async {
      expect(await gallery.bytesFor(asset), isNull);
    },
  );
}
