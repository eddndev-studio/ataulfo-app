import '../../domain/repositories/camera_capture.dart';
import '../../domain/repositories/media_file_picker.dart';

/// [CameraCapture] nulo para plataformas sin cámara invocable (escritorio,
/// web): `isSupported()` responde false, así que la UI nunca ofrece el
/// destino. Si algo lo llama igual, capturar resuelve null (como una captura
/// cancelada) en vez de lanzar.
class NoopCameraCapture implements CameraCapture {
  const NoopCameraCapture();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<PickedMedia?> takePhoto() async => null;

  @override
  Future<PickedMedia?> takeVideo() async => null;
}
