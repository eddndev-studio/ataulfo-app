import '../data/repositories/noop_device_gallery.dart';
import '../data/repositories/photo_manager_device_gallery.dart';
import '../domain/repositories/device_gallery_port.dart';

/// Elige el [DeviceGalleryPort] según la plataforma: sólo Android expone el
/// carrete real (vía `photo_manager`); el resto (escritorio/Linux del dev
/// box, web) usa un Noop para que la app corra sin galería nativa. Aísla la
/// selección del bootstrap para poder probarla sin canales de plataforma.
///
/// `androidGallery` se inyecta sólo en tests; en producción construye el
/// [PhotoManagerDeviceGallery] real.
class DeviceGalleryResolver {
  DeviceGalleryResolver({
    required this.isAndroid,
    DeviceGalleryPort Function()? androidGallery,
  }) : _androidGallery = androidGallery ?? PhotoManagerDeviceGallery.new;

  final bool isAndroid;
  final DeviceGalleryPort Function() _androidGallery;

  DeviceGalleryPort resolve() =>
      isAndroid ? _androidGallery() : const NoopDeviceGallery();
}
