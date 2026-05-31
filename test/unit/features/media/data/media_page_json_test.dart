import 'package:ataulfo/features/media/data/cache/media_page_json.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final page = MediaPage(
    nextCursor: 'cur-9',
    assets: <MediaAsset>[
      MediaAsset(
        ref: 'tenant/o/media/a.png',
        previewUrl: 'https://signed/a',
        filename: 'a.png',
        contentType: 'image/png',
        size: 123,
        createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      ),
      // previewUrl null + un documento: cubre el nullable y otra familia.
      MediaAsset(
        ref: 'tenant/o/media/b.pdf',
        previewUrl: null,
        filename: 'informe.pdf',
        contentType: 'application/pdf',
        size: 9999,
        createdAt: DateTime.utc(2025, 12, 31, 23, 59, 59),
      ),
    ],
  );

  test('roundtrip entity→json→entity preserva todos los campos', () {
    final restored = mediaPageFromJson(mediaPageToJson(page));
    expect(restored, page); // MediaPage tiene == estructural
  });

  test('createdAt se preserva en UTC con precisión', () {
    final restored = mediaPageFromJson(mediaPageToJson(page));
    expect(restored.assets.first.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(restored.assets.first.createdAt.isUtc, isTrue);
  });

  test('previewUrl null sobrevive el roundtrip', () {
    final restored = mediaPageFromJson(mediaPageToJson(page));
    expect(restored.assets[1].previewUrl, isNull);
  });

  test('página vacía roundtrip', () {
    const empty = MediaPage(assets: <MediaAsset>[], nextCursor: '');
    expect(mediaPageFromJson(mediaPageToJson(empty)), empty);
  });
}
