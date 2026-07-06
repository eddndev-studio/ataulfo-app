import 'dart:io';
import 'dart:typed_data';

import 'package:ataulfo/features/messages/data/media/share_plus_media_sharer.dart';
import 'package:ataulfo/features/messages/domain/repositories/media_sharer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sharer_test');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  test(
    'materializa los bytes a archivo (nombre saneado) y lo comparte',
    () async {
      final shared = <String>[];
      final sharer = SharePlusMediaSharer(
        cacheDir: () async => tmp,
        shareFile: (path) async => shared.add(path),
      );
      final bytes = Uint8List.fromList(<int>[1, 2, 3]);

      await sharer.share(bytes: bytes, filename: 'foto rara/..#.jpg');

      expect(shared, hasLength(1));
      final file = File(shared.single);
      expect(file.existsSync(), isTrue);
      expect(await file.readAsBytes(), bytes);
      // El nombre se sanea (el share sheet recibe un path seguro) y conserva
      // la extensión, que decide cómo lo trata la app receptora.
      expect(shared.single, endsWith('.jpg'));
      expect(shared.single, isNot(contains('#')));
    },
  );

  test(
    'un fallo del share sheet se propaga como MediaShareException',
    () async {
      final sharer = SharePlusMediaSharer(
        cacheDir: () async => tmp,
        shareFile: (_) async =>
            throw const MediaShareException('compartir no disponible'),
      );

      expect(
        () => sharer.share(bytes: Uint8List(1), filename: 'a.bin'),
        throwsA(isA<MediaShareException>()),
      );
    },
  );
}
