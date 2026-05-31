import 'package:ataulfo/features/media/data/dto/media_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UploadResp.fromJson', () {
    test('ref obligatorio ausente => FormatException', () {
      expect(
        () => UploadResp.fromJson(<String, dynamic>{'url': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('ref de tipo equivocado => FormatException', () {
      expect(
        () => UploadResp.fromJson(<String, dynamic>{'ref': 42}),
        throwsA(isA<FormatException>()),
      );
    });

    test('url presente pero no String => FormatException', () {
      expect(
        () => UploadResp.fromJson(<String, dynamic>{'ref': 'r', 'url': 7}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('MediaAssetResp.fromJson', () {
    Map<String, dynamic> valid() => <String, dynamic>{
      'ref': 'r',
      'url': 'u',
      'filename': 'f',
      'content_type': 'image/png',
      'size': 5,
      'created_at': '2026-05-30T12:00:00Z',
    };

    test('campos obligatorios completos => OK', () {
      final r = MediaAssetResp.fromJson(valid());
      expect(r.ref, 'r');
      expect(r.url, 'u');
      expect(r.filename, 'f');
      expect(r.contentType, 'image/png');
      expect(r.size, 5);
      expect(r.createdAt, '2026-05-30T12:00:00Z');
    });

    test('filename ausente => FormatException', () {
      final j = valid()..remove('filename');
      expect(() => MediaAssetResp.fromJson(j), throwsA(isA<FormatException>()));
    });

    test('size de tipo equivocado => FormatException', () {
      final j = valid()..['size'] = 'big';
      expect(() => MediaAssetResp.fromJson(j), throwsA(isA<FormatException>()));
    });

    test('created_at ausente => FormatException', () {
      final j = valid()..remove('created_at');
      expect(() => MediaAssetResp.fromJson(j), throwsA(isA<FormatException>()));
    });
  });

  group('MediaListResp.fromJson', () {
    test('assets + next_cursor => parsea ambos', () {
      final r = MediaListResp.fromJson(<String, dynamic>{
        'assets': <dynamic>[
          <String, dynamic>{
            'ref': 'r',
            'filename': 'f',
            'content_type': 'image/png',
            'size': 1,
            'created_at': '2026-05-30T12:00:00Z',
          },
        ],
        'next_cursor': 'opaque',
      });
      expect(r.assets, hasLength(1));
      expect(r.nextCursor, 'opaque');
    });

    test('next_cursor vacío => cadena vacía (no null)', () {
      final r = MediaListResp.fromJson(<String, dynamic>{
        'assets': <dynamic>[],
        'next_cursor': '',
      });
      expect(r.assets, isEmpty);
      expect(r.nextCursor, '');
    });

    test('assets no es lista => FormatException', () {
      expect(
        () => MediaListResp.fromJson(<String, dynamic>{
          'assets': 'nope',
          'next_cursor': '',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('next_cursor ausente => FormatException (drift de contrato)', () {
      expect(
        () => MediaListResp.fromJson(<String, dynamic>{'assets': <dynamic>[]}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
