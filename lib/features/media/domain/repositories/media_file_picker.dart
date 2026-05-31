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

/// Puerto consumer-defined para elegir un archivo del dispositivo. El dominio
/// declara el contrato; el adaptador concreto (sobre `image_picker`) vive en
/// `data/`. Devuelve `null` cuando el usuario cancela la selección.
abstract interface class MediaFilePicker {
  Future<PickedMedia?> pick();
}
