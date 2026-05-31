import 'dart:io';

import 'package:ataulfo/features/media/data/cache/file_media_page_store.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('media_pages_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  FileMediaPageStore store() =>
      FileMediaPageStore(directoryProvider: () async => tmp);

  MediaPage page(String ref) => MediaPage(
    nextCursor: 'c',
    assets: <MediaAsset>[
      MediaAsset(
        ref: ref,
        previewUrl: 'https://x/$ref',
        filename: 'f',
        contentType: 'image/png',
        size: 1,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ],
  );

  test('write luego read del mismo (org,type) devuelve la página', () async {
    final s = store();
    await s.write('org-1', 'image', page('a'));
    expect(await s.read('org-1', 'image'), page('a'));
  });

  test('read de algo nunca escrito devuelve null', () async {
    expect(await store().read('org-1', 'image'), isNull);
  });

  test('type=null es una clave distinta de una familia concreta', () async {
    final s = store();
    await s.write('org-1', null, page('all'));
    await s.write('org-1', 'image', page('img'));
    expect(await s.read('org-1', null), page('all'));
    expect(await s.read('org-1', 'image'), page('img'));
  });

  test('orgs distintas están aisladas (frontera multitenant)', () async {
    final s = store();
    await s.write('org-1', 'image', page('uno'));
    await s.write('org-2', 'image', page('dos'));
    expect(await s.read('org-1', 'image'), page('uno'));
    expect(await s.read('org-2', 'image'), page('dos'));
  });

  test('clear borra todo (toda org y tipo)', () async {
    final s = store();
    await s.write('org-1', 'image', page('a'));
    await s.write('org-2', null, page('b'));
    await s.clear();
    expect(await s.read('org-1', 'image'), isNull);
    expect(await s.read('org-2', null), isNull);
  });

  test('un archivo corrupto se trata como miss (null, sin lanzar)', () async {
    final s = store();
    await s.write('org-1', 'image', page('a'));
    // Corromper el archivo persistido.
    final dir = Directory('${tmp.path}/media_pages');
    final f = dir.listSync().whereType<File>().first;
    await f.writeAsString('}{ no es json valido');
    expect(await s.read('org-1', 'image'), isNull);
  });
}
