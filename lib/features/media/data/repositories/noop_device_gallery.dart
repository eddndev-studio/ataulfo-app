import 'dart:typed_data';

import '../../domain/repositories/device_gallery_port.dart';
import '../../domain/repositories/media_file_picker.dart';

/// [DeviceGalleryPort] nulo para plataformas sin carrete accesible
/// (escritorio, web): `availability()` responde `unsupported`, así que la UI
/// nunca ofrece el destino Galería. Si algo lo consulta igual, responde
/// vacío/null (como un carrete sin media) en vez de lanzar.
class NoopDeviceGallery implements DeviceGalleryPort {
  const NoopDeviceGallery();

  @override
  Future<DeviceGalleryAvailability> availability() async =>
      DeviceGalleryAvailability.unsupported;

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
