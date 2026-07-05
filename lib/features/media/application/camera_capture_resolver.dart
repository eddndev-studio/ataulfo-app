import '../data/repositories/image_picker_camera_capture.dart';
import '../data/repositories/noop_camera_capture.dart';
import '../domain/repositories/camera_capture.dart';

/// Elige el [CameraCapture] según la plataforma: sólo Android usa la cámara
/// real (vía `image_picker`); el resto (escritorio/Linux del dev box, web)
/// usa un Noop para que la app corra sin cámara nativa. Aísla la selección
/// del bootstrap para poder probarla sin canales de plataforma.
///
/// `androidCapture` se inyecta sólo en tests; en producción construye el
/// [ImagePickerCameraCapture] real.
class CameraCaptureResolver {
  CameraCaptureResolver({
    required this.isAndroid,
    CameraCapture Function()? androidCapture,
  }) : _androidCapture = androidCapture ?? ImagePickerCameraCapture.new;

  final bool isAndroid;
  final CameraCapture Function() _androidCapture;

  CameraCapture resolve() =>
      isAndroid ? _androidCapture() : const NoopCameraCapture();
}
