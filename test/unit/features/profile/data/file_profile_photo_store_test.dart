import 'dart:io';
import 'dart:typed_data';

import 'package:ataulfo/features/profile/data/cache/file_profile_photo_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('profile_photos_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  FileProfilePhotoStore store() =>
      FileProfilePhotoStore(directoryProvider: () async => tmp);

  final bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
  // La clave es account-scoped: `'$botId $chatLid'`. No tiene '/', pero la
  // codificamos igual a base64url para mantener un único segmento plano.
  const key = 'bot-123 12345@lid';

  test('write luego read devuelve los mismos bytes', () async {
    final s = store();
    await s.write(key, bytes);
    final cached = await s.read(key);
    expect(cached, isNotNull);
    expect(cached!.bytes, bytes);
  });

  test('fetchedAt ~ ahora (el mtime del archivo)', () async {
    final s = store();
    final before = DateTime.now();
    await s.write(key, bytes);
    final cached = await s.read(key);
    final after = DateTime.now();
    expect(cached, isNotNull);
    // El mtime puede truncar a segundos en algunos filesystems: holgura amplia.
    expect(
      cached!.fetchedAt.isAfter(before.subtract(const Duration(seconds: 2))),
      isTrue,
    );
    expect(
      cached.fetchedAt.isBefore(after.add(const Duration(seconds: 2))),
      isTrue,
    );
  });

  test('un marcador de 0 bytes (sin foto) se lee como bytes == null', () async {
    final s = store();
    await s.write(key, null);
    final cached = await s.read(key);
    expect(cached, isNotNull);
    expect(cached!.bytes, isNull);
  });

  test('read de una clave nunca escrita devuelve null (miss)', () async {
    expect(await store().read('bot-x inexistente@lid'), isNull);
  });

  test('clear() borra todo lo cacheado', () async {
    final s = store();
    await s.write(key, bytes);
    await s.clear();
    expect(await s.read(key), isNull);
  });
}
