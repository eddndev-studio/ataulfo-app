import 'dart:io';
import 'dart:typed_data';

import 'package:ataulfo/features/media/data/cache/file_media_byte_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('media_bytes_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  FileMediaByteStore store() =>
      FileMediaByteStore(directoryProvider: () async => tmp);

  final bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
  // Un ref realista: BARE, canónico, con '/' y extensión — el nombre de archivo
  // del cache NO puede ser el ref tal cual (los '/' abrirían subdirectorios).
  const ref = 'tenant/org-123/media/abc.png';

  test('write luego read devuelve los mismos bytes', () async {
    final s = store();
    await s.write(ref, bytes);
    expect(await s.read(ref), bytes);
  });

  test('read de un ref nunca escrito devuelve null (miss)', () async {
    expect(await store().read('tenant/org-123/media/inexistente.png'), isNull);
  });

  test('dos refs distintos no colisionan', () async {
    final s = store();
    final other = Uint8List.fromList(<int>[9, 9, 9]);
    await s.write(ref, bytes);
    await s.write('tenant/org-123/media/zzz.png', other);
    expect(await s.read(ref), bytes);
    expect(await s.read('tenant/org-123/media/zzz.png'), other);
  });

  test('un ref con / no crea subdirectorios bajo el cache dir', () async {
    final s = store();
    await s.write(ref, bytes);
    // El ref tiene 3 niveles de '/': si el store los respetara, habría carpetas
    // anidadas. El nombre debe ser plano (un único archivo, sin subdirs del ref).
    final mediaDir = Directory('${tmp.path}/media_bytes');
    final entries = mediaDir.listSync();
    expect(entries.whereType<File>(), hasLength(1));
    expect(entries.whereType<Directory>(), isEmpty);
  });
}
