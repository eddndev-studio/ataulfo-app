import 'package:ataulfo/features/messages/domain/attachment_intake.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ({String filename, int sizeBytes}) f(String name, int size) =>
      (filename: name, sizeBytes: size);

  group('planAttachmentBatch', () {
    test('todos caben: acepta en orden, sin rechazos', () {
      final r = planAttachmentBatch(
        picked: <({String filename, int sizeBytes})>[
          f('a.png', 10),
          f('b.pdf', 20),
        ],
        currentCount: 0,
      );
      expect(r.acceptedIndexes, <int>[0, 1]);
      expect(r.overflow, isFalse);
      expect(r.tooLarge, isEmpty);
    });

    test('un archivo sobre 64 MB se rechaza por peso, el resto pasa', () {
      final r = planAttachmentBatch(
        picked: <({String filename, int sizeBytes})>[
          f('ok.png', 10),
          f('enorme.mov', 64 * 1024 * 1024 + 1),
          f('otro.pdf', 30),
        ],
        currentCount: 0,
      );
      expect(r.acceptedIndexes, <int>[0, 2]);
      expect(r.tooLarge, <String>['enorme.mov']);
      expect(r.overflow, isFalse);
    });

    test('exactamente 64 MB pasa (el tope es estricto)', () {
      final r = planAttachmentBatch(
        picked: <({String filename, int sizeBytes})>[
          f('justo.bin', 64 * 1024 * 1024),
        ],
        currentCount: 0,
      );
      expect(r.acceptedIndexes, <int>[0]);
      expect(r.tooLarge, isEmpty);
    });

    test('pasar de 10 en el lote: acepta hasta el tope y marca overflow', () {
      final picked = <({String filename, int sizeBytes})>[
        for (var i = 0; i < 12; i++) f('f$i.png', 1),
      ];
      final r = planAttachmentBatch(picked: picked, currentCount: 0);
      expect(r.acceptedIndexes.length, 10);
      expect(r.acceptedIndexes, List<int>.generate(10, (i) => i));
      expect(r.overflow, isTrue);
    });

    test('cuenta los adjuntos ya presentes contra el tope de 10', () {
      final r = planAttachmentBatch(
        picked: <({String filename, int sizeBytes})>[
          f('a.png', 1),
          f('b.png', 1),
          f('c.png', 1),
        ],
        currentCount: 8,
      );
      expect(r.acceptedIndexes, <int>[0, 1]); // sólo caben 2 más
      expect(r.overflow, isTrue);
    });

    test('peso y overflow combinados: el pesado no ocupa cupo', () {
      final r = planAttachmentBatch(
        picked: <({String filename, int sizeBytes})>[
          f('big.zip', 64 * 1024 * 1024 + 1),
          f('a.png', 1),
        ],
        currentCount: 9,
      );
      expect(r.acceptedIndexes, <int>[1]);
      expect(r.tooLarge, <String>['big.zip']);
      expect(r.overflow, isFalse);
    });
  });
}
