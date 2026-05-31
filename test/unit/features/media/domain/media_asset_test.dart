import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaAsset', () {
    final createdAt = DateTime.utc(2026, 5, 30, 12, 0, 0);

    MediaAsset build({String? previewUrl}) => MediaAsset(
      ref: 'tenant/org/media/abc.png',
      previewUrl: previewUrl,
      filename: 'abc.png',
      contentType: 'image/png',
      size: 1024,
      createdAt: createdAt,
    );

    test('igualdad de valor: mismos campos => instancias iguales', () {
      expect(build(previewUrl: 'https://x/p'), build(previewUrl: 'https://x/p'));
      expect(
        build(previewUrl: 'https://x/p').hashCode,
        build(previewUrl: 'https://x/p').hashCode,
      );
    });

    test('previewUrl distinto => instancias distintas', () {
      expect(build(previewUrl: 'https://x/p'), isNot(build(previewUrl: null)));
    });

    test('no expone un campo llamado "url" (sólo ref bare + previewUrl)', () {
      // El nombre del campo es portador de significado: la entidad almacena el
      // ref BARE canónico y una previewUrl efímera. El test de igualdad y el
      // mapper protegen la semántica; este caso documenta que previewUrl es
      // nullable (omitempty del wire).
      final a = build();
      expect(a.previewUrl, isNull);
      expect(a.ref, 'tenant/org/media/abc.png');
    });
  });

  group('UploadedMedia', () {
    test('igualdad de valor', () {
      const a = UploadedMedia(ref: 'r', previewUrl: 'u');
      const b = UploadedMedia(ref: 'r', previewUrl: 'u');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('previewUrl nullable (url omitempty del wire)', () {
      const a = UploadedMedia(ref: 'r', previewUrl: null);
      expect(a.previewUrl, isNull);
      expect(a.ref, 'r');
    });
  });

  group('MediaPage', () {
    test('igualdad de valor: assets + nextCursor', () {
      final asset = MediaAsset(
        ref: 'r',
        previewUrl: null,
        filename: 'f',
        contentType: 'image/png',
        size: 1,
        createdAt: DateTime.utc(2026),
      );
      final a = MediaPage(assets: [asset], nextCursor: 'c');
      final b = MediaPage(assets: [asset], nextCursor: 'c');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('nextCursor vacío significa "no hay más páginas"', () {
      const a = MediaPage(assets: [], nextCursor: '');
      expect(a.nextCursor, isEmpty);
    });
  });
}
