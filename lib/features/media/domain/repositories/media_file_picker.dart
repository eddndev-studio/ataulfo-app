import 'dart:typed_data';

/// Un archivo elegido por el usuario, en memoria. Expone [bytes] + [filename]
/// deliberadamente — NO un `dart:io File`. Esto mantiene la subida testeable sin
/// tocar el sistema de archivos y desacopla el dominio de la plataforma (web,
/// móvil): el datasource sube los bytes vía `MultipartFile.fromBytes`.
class PickedMedia {
  const PickedMedia({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// Puerto consumer-defined para elegir archivos del dispositivo. El dominio
/// declara el contrato; el adaptador concreto (sobre `file_picker`) vive en
/// `data/`.
abstract interface class MediaFilePicker {
  /// Elige UN archivo. `null` cuando el usuario cancela.
  Future<PickedMedia?> pick();

  /// Elige VARIOS archivos (subida en lote). Lista vacía cuando el usuario
  /// cancela o ninguno trajo bytes.
  Future<List<PickedMedia>> pickMultiple();
}
