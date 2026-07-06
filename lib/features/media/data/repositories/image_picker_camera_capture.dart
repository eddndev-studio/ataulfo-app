import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/repositories/camera_capture.dart';
import '../../domain/repositories/media_file_picker.dart';

/// Adaptador del puerto [CameraCapture] sobre el plugin `image_picker` —
/// la vía para invocar la cámara nativa del SO (`file_picker` sólo elige
/// archivos existentes). La foto/video capturado se materializa EN MEMORIA
/// (`readAsBytes`), coherente con [PickedMedia].
///
/// `isSupported()` responde true incondicional: el plugin no expone un probe
/// de cámara, así que la selección de plataforma vive en el resolver (que
/// sólo construye este adaptador donde la cámara existe; el resto recibe el
/// Noop).
///
/// La llamada nativa NO se unit-testea (requiere el plugin; se valida en
/// smoke device); el MAPEO del resultado sí — extraído a [pickedFromXFile].
/// `picker` se inyecta sólo en tests; en producción construye el real.
class ImagePickerCameraCapture implements CameraCapture {
  ImagePickerCameraCapture({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<bool> isSupported() async => true;

  /// Cancelar resuelve `null`; cualquier error del plugin (cámara ocupada,
  /// permiso revocado, activity destruida…) degrada a la falla TIPADA del
  /// puerto — nunca la excepción cruda de plataforma hacia la UI.
  @override
  Future<PickedMedia?> takePhoto() async {
    try {
      return await pickedFromXFile(
        await _picker.pickImage(source: ImageSource.camera),
      );
    } catch (_) {
      throw const CameraCaptureFailure();
    }
  }

  @override
  Future<PickedMedia?> takeVideo() async {
    try {
      return await pickedFromXFile(
        await _picker.pickVideo(source: ImageSource.camera),
      );
    } catch (_) {
      throw const CameraCaptureFailure();
    }
  }
}

/// Mapea el resultado de `image_picker` al puerto. Devuelve null cuando el
/// usuario cancela la captura (`file == null`). El filename es `XFile.name`
/// (basename del archivo temporal que escribe la cámara, con extensión real
/// — de ella se infiere el `type` de envío).
@visibleForTesting
Future<PickedMedia?> pickedFromXFile(XFile? file) async {
  if (file == null) return null;
  return PickedMedia(bytes: await file.readAsBytes(), filename: file.name);
}
