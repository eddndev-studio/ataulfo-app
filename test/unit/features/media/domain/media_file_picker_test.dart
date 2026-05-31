import 'dart:typed_data';

import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

// Doble en memoria del puerto: confirma que el contrato devuelve bytes +
// filename (NO un dart:io File) y null al cancelar. El adapter concreto sobre
// image_picker es un wrapper delgado sin lógica y NO se unit-testea (el plugin
// nativo no corre bajo `flutter test`).
class _FakePicker implements MediaFilePicker {
  _FakePicker(this._result);
  final PickedMedia? _result;
  @override
  Future<PickedMedia?> pick() async => _result;
}

void main() {
  group('MediaFilePicker (contrato)', () {
    test('pick devuelve PickedMedia con bytes + filename', () async {
      final bytes = Uint8List.fromList(<int>[9, 8, 7]);
      final picker = _FakePicker(PickedMedia(bytes: bytes, filename: 'p.png'));

      final picked = await picker.pick();

      expect(picked, isNotNull);
      expect(picked!.bytes, bytes);
      expect(picked.filename, 'p.png');
    });

    test('pick devuelve null cuando el usuario cancela', () async {
      final picker = _FakePicker(null);
      expect(await picker.pick(), isNull);
    });
  });

  group('PickedMedia', () {
    test('expone bytes (Uint8List) y filename (String) — sin dart:io File', () {
      final picked = PickedMedia(
        bytes: Uint8List.fromList(<int>[1]),
        filename: 'a.jpg',
      );
      expect(picked.bytes, isA<Uint8List>());
      expect(picked.filename, isA<String>());
    });
  });
}
