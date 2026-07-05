import 'media_file_picker.dart';

/// Puerto consumer-defined para capturar contenido NUEVO con la cámara del
/// dispositivo. Capacidad distinta de [MediaFilePicker] (elegir archivos que
/// ya existen): el adaptador concreto (sobre `image_picker`) vive en `data/`.
///
/// Reusa [PickedMedia] (bytes + filename, sin `dart:io`): lo capturado entra
/// al mismo camino de subida que cualquier archivo elegido.
abstract interface class CameraCapture {
  /// La plataforma puede invocar una cámara real. Falso ⇒ la UI no ofrece el
  /// destino de cámara.
  Future<bool> isSupported();

  /// Abre la cámara en modo foto. `null` cuando el usuario cancela.
  Future<PickedMedia?> takePhoto();

  /// Abre la cámara en modo video. `null` cuando el usuario cancela.
  Future<PickedMedia?> takeVideo();
}
