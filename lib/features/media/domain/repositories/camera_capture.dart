import 'media_file_picker.dart';

/// La cámara no se pudo abrir o la captura falló (distinto de CANCELAR, que
/// resuelve `null` y no merece aviso). Los adaptadores mapean cualquier error
/// crudo del plugin/plataforma a esta falla tipada: la UI sólo tiene que
/// atrapar esto para avisar, nunca una excepción de plataforma sin contrato.
class CameraCaptureFailure implements Exception {
  const CameraCaptureFailure();
}

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

  /// Abre la cámara en modo foto. `null` cuando el usuario cancela; un fallo
  /// real lanza [CameraCaptureFailure].
  Future<PickedMedia?> takePhoto();

  /// Abre la cámara en modo video. `null` cuando el usuario cancela; un fallo
  /// real lanza [CameraCaptureFailure].
  Future<PickedMedia?> takeVideo();
}
