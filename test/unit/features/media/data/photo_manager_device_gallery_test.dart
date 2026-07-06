import 'package:ataulfo/features/media/data/repositories/photo_manager_device_gallery.dart';
import 'package:ataulfo/features/media/domain/repositories/device_gallery_port.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';

/// Sólo el MAPEO AssetEntity → DeviceMediaAsset es unit-testeable: las
/// llamadas nativas del plugin (permiso, paginado, miniaturas, bytes) exigen
/// canales de plataforma y se validan en smoke device. `AssetEntity` es
/// construible en Dart puro, así que el mapeo se prueba sin plataforma.
void main() {
  group('availabilityFromPermission', () {
    test('acceso total o limitado ⇒ disponible', () {
      expect(
        availabilityFromPermission(PermissionState.authorized),
        DeviceGalleryAvailability.available,
      );
      expect(
        availabilityFromPermission(PermissionState.limited),
        DeviceGalleryAvailability.available,
      );
    });

    test(
      'denegado/restringido/sin decidir ⇒ denegado (la UI ofrece Ajustes)',
      () {
        expect(
          availabilityFromPermission(PermissionState.denied),
          DeviceGalleryAvailability.denied,
        );
        expect(
          availabilityFromPermission(PermissionState.restricted),
          DeviceGalleryAvailability.denied,
        );
        expect(
          availabilityFromPermission(PermissionState.notDetermined),
          DeviceGalleryAvailability.denied,
        );
      },
    );
  });

  test('una imagen mapea id + título como filename, sin duración', () {
    final entity = AssetEntity(
      id: '42',
      typeInt: AssetType.image.index,
      width: 100,
      height: 100,
      title: 'IMG_001.jpg',
    );

    final asset = deviceAssetFromEntity(entity);

    expect(asset.id, '42');
    expect(asset.filename, 'IMG_001.jpg');
    expect(asset.isVideo, isFalse);
    expect(asset.durationMs, isNull);
  });

  test('un video mapea isVideo + duración en ms', () {
    final entity = AssetEntity(
      id: '7',
      typeInt: AssetType.video.index,
      width: 100,
      height: 100,
      duration: 12,
      title: 'VID_002.mp4',
    );

    final asset = deviceAssetFromEntity(entity);

    expect(asset.isVideo, isTrue);
    expect(asset.durationMs, 12000);
    expect(asset.filename, 'VID_002.mp4');
  });

  test('sin título usa un nombre de respaldo con extensión por tipo', () {
    final image = AssetEntity(
      id: '9',
      typeInt: AssetType.image.index,
      width: 1,
      height: 1,
    );
    final video = AssetEntity(
      id: '10',
      typeInt: AssetType.video.index,
      width: 1,
      height: 1,
      title: '',
    );

    expect(deviceAssetFromEntity(image).filename, '9.jpg');
    expect(deviceAssetFromEntity(video).filename, '10.mp4');
  });
}
