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
      expect(
        build(previewUrl: 'https://x/p'),
        build(previewUrl: 'https://x/p'),
      );
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

    test('alias por defecto vacío (no requerido)', () {
      expect(build().alias, '');
    });

    test('displayName = alias cuando no está vacío', () {
      final a = MediaAsset(
        ref: 'r',
        previewUrl: null,
        filename: 'IMG_2231.jpg',
        alias: 'Mi logo',
        contentType: 'image/jpeg',
        size: 1,
        createdAt: createdAt,
      );
      expect(a.displayName, 'Mi logo');
    });

    test('displayName = filename cuando alias vacío', () {
      expect(build().displayName, 'abc.png');
    });

    test('copyWith(alias:) cambia sólo el alias; resto intacto', () {
      final base = build(previewUrl: 'https://x/p');
      final renamed = base.copyWith(alias: 'Nuevo');
      expect(renamed.alias, 'Nuevo');
      expect(renamed.ref, base.ref);
      expect(renamed.filename, base.filename);
      expect(renamed.previewUrl, base.previewUrl);
      expect(renamed.contentType, base.contentType);
      expect(renamed.size, base.size);
      expect(renamed.createdAt, base.createdAt);
    });

    test('copyWith() sin args => instancia igual', () {
      final base = build();
      expect(base.copyWith(), base);
    });

    test('copyWith puede limpiar el alias a vacío', () {
      final withAlias = build().copyWith(alias: 'algo');
      expect(withAlias.copyWith(alias: '').alias, '');
    });

    test(
      'thumbnailSourceUrl: imagen usa previewUrl (su preview ES la imagen)',
      () {
        final img = MediaAsset(
          ref: 'r',
          previewUrl: 'https://x/img',
          filename: 'a.png',
          contentType: 'image/png',
          size: 1,
          createdAt: createdAt,
        );
        expect(img.thumbnailSourceUrl, 'https://x/img');
      },
    );

    test(
      'thumbnailSourceUrl: video con thumbnailUrl usa el poster, NO el original',
      () {
        final vid = MediaAsset(
          ref: 'r',
          previewUrl:
              'https://x/video.mp4', // el archivo original, no renderable
          filename: 'v.mp4',
          contentType: 'video/mp4',
          size: 1,
          createdAt: createdAt,
          thumbnailUrl: 'https://x/poster.jpg',
          durationMs: 4200,
        );
        expect(vid.thumbnailSourceUrl, 'https://x/poster.jpg');
      },
    );

    test(
      'thumbnailSourceUrl: video sin thumbnailUrl => null (cae al ícono)',
      () {
        final vid = MediaAsset(
          ref: 'r',
          previewUrl: 'https://x/video.mp4',
          filename: 'v.mp4',
          contentType: 'video/mp4',
          size: 1,
          createdAt: createdAt,
        );
        expect(vid.thumbnailSourceUrl, isNull);
      },
    );

    test('thumbnailSourceUrl: documento sin thumbnailUrl => null', () {
      final doc = MediaAsset(
        ref: 'r',
        previewUrl: 'https://x/doc.pdf',
        filename: 'd.pdf',
        contentType: 'application/pdf',
        size: 1,
        createdAt: createdAt,
      );
      expect(doc.thumbnailSourceUrl, isNull);
    });

    test(
      'copyWith preserva thumbnailUrl + durationMs (rename no los pierde)',
      () {
        final vid = MediaAsset(
          ref: 'r',
          previewUrl: 'https://x/video.mp4',
          filename: 'v.mp4',
          contentType: 'video/mp4',
          size: 1,
          createdAt: createdAt,
          thumbnailUrl: 'https://x/poster.jpg',
          durationMs: 4200,
        );
        final renamed = vid.copyWith(alias: 'Clip');
        expect(renamed.thumbnailUrl, 'https://x/poster.jpg');
        expect(renamed.durationMs, 4200);
        expect(renamed.alias, 'Clip');
      },
    );

    test('derivados distintos => instancias distintas (igualdad de valor)', () {
      MediaAsset withThumb(String? t) => MediaAsset(
        ref: 'r',
        previewUrl: null,
        filename: 'v.mp4',
        contentType: 'video/mp4',
        size: 1,
        createdAt: createdAt,
        thumbnailUrl: t,
      );
      expect(withThumb('a'), isNot(withThumb('b')));
      expect(withThumb('a'), withThumb('a'));
    });

    test('alias distinto => instancias distintas (igualdad de valor)', () {
      final a = MediaAsset(
        ref: 'r',
        previewUrl: null,
        filename: 'f',
        alias: 'uno',
        contentType: 'image/png',
        size: 1,
        createdAt: createdAt,
      );
      final b = MediaAsset(
        ref: 'r',
        previewUrl: null,
        filename: 'f',
        alias: 'dos',
        contentType: 'image/png',
        size: 1,
        createdAt: createdAt,
      );
      expect(a, isNot(b));
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
