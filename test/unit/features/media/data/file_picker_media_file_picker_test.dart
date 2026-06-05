import 'dart:typed_data';

import 'package:ataulfo/features/media/data/repositories/file_picker_media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

// El adaptador sobre `file_picker` es un wrapper delgado: la llamada nativa
// (`FilePicker.platform.pickFiles`) NO se unit-testea (necesita el plugin, se
// valida en smoke device). Pero el MAPEO `FilePickerResult? → PickedMedia?`
// es lógica pura y SÍ se testea con tipos reales de file_picker.
void main() {
  group('pickedFromResult', () {
    test('mapea el primer archivo a PickedMedia con bytes + filename', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final result = FilePickerResult([
        PlatformFile(name: 'informe.pdf', size: bytes.length, bytes: bytes),
      ]);

      final picked = pickedFromResult(result);

      expect(picked, isA<PickedMedia>());
      expect(picked!.filename, 'informe.pdf');
      expect(picked.bytes, bytes);
    });

    test('result null (cancelado) ⇒ null', () {
      expect(pickedFromResult(null), isNull);
    });

    test('sin archivos ⇒ null', () {
      expect(pickedFromResult(const FilePickerResult([])), isNull);
    });

    test(
      'primer archivo sin bytes (withData falló) ⇒ null, no PickedMedia con bytes null',
      () {
        final result = FilePickerResult([PlatformFile(name: 'x.bin', size: 0)]);
        expect(pickedFromResult(result), isNull);
      },
    );
  });

  group('pickedListFromResult (multi-archivo)', () {
    test('mapea TODOS los archivos con bytes', () {
      final a = Uint8List.fromList([1, 2]);
      final b = Uint8List.fromList([3, 4, 5]);
      final result = FilePickerResult([
        PlatformFile(name: 'a.png', size: a.length, bytes: a),
        PlatformFile(name: 'b.pdf', size: b.length, bytes: b),
      ]);

      final picked = pickedListFromResult(result);

      expect(picked, hasLength(2));
      expect(picked[0].filename, 'a.png');
      expect(picked[0].bytes, a);
      expect(picked[1].filename, 'b.pdf');
    });

    test('result null (cancelado) ⇒ lista vacía', () {
      expect(pickedListFromResult(null), isEmpty);
    });

    test('omite los archivos sin bytes, conserva el resto', () {
      final a = Uint8List.fromList([1, 2]);
      final result = FilePickerResult([
        PlatformFile(name: 'ok.png', size: a.length, bytes: a),
        PlatformFile(name: 'sinbytes.bin', size: 0), // bytes null ⇒ se omite
      ]);

      final picked = pickedListFromResult(result);

      expect(picked, hasLength(1));
      expect(picked.single.filename, 'ok.png');
    });
  });
}
