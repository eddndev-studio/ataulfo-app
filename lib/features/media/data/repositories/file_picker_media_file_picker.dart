import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../domain/repositories/media_file_picker.dart';

/// Adaptador del puerto [MediaFilePicker] sobre el plugin `file_picker`.
///
/// A diferencia de `image_picker` (sólo imágenes), `file_picker` abre cualquier
/// tipo de archivo (audio, video, PDF, Office, …) — es el desbloqueo para enviar
/// media no-imagen en pasos de flujo. `pickFiles(withData: true)` trae los bytes
/// EN MEMORIA (sin tocar `dart:io`), coherente con [PickedMedia], que expone
/// bytes + filename para subir vía `MultipartFile.fromBytes`.
///
/// La llamada nativa NO se unit-testea (requiere el plugin; se valida en smoke
/// device); el MAPEO del resultado sí — extraído a [pickedFromResult].
class FilePickerMediaFilePicker implements MediaFilePicker {
  @override
  Future<PickedMedia?> pick() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    return pickedFromResult(result);
  }
}

/// Mapea el resultado de `file_picker` al puerto. Devuelve null cuando el
/// usuario cancela (`result == null`), cuando no vino ningún archivo, o cuando
/// el primer archivo no trae bytes (defensa: `withData` debería poblarlos, pero
/// no se construye un [PickedMedia] con bytes nulos). Sólo el primer archivo:
/// la subida es de un asset a la vez.
@visibleForTesting
PickedMedia? pickedFromResult(FilePickerResult? result) {
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.first;
  final bytes = file.bytes;
  if (bytes == null) return null;
  return PickedMedia(bytes: bytes, filename: file.name);
}
