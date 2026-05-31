import 'package:image_picker/image_picker.dart';

import '../../domain/repositories/media_file_picker.dart';

/// Adaptador del puerto [MediaFilePicker] sobre el plugin `image_picker`.
///
/// Wrapper delgado SIN lógica: abre la galería, lee los bytes del `XFile` y los
/// envuelve en [PickedMedia]. `XFile.readAsBytes()`/`.name` son
/// cross-platform — no toca `dart:io`. NO se unit-testea: ejercitarlo requiere
/// el plugin nativo, que no corre bajo `flutter test`; su corrección se valida
/// en el smoke device.
class ImagePickerMediaFilePicker implements MediaFilePicker {
  ImagePickerMediaFilePicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedMedia?> pick() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    return PickedMedia(bytes: await file.readAsBytes(), filename: file.name);
  }
}
