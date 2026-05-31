import 'package:ataulfo/features/media/data/dto/media_dto.dart';
import 'package:ataulfo/features/media/data/mappers/media_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaMapper.assetRespToEntity (LINCHPIN: ref BARE vs previewUrl)', () {
    test(
      'la previewUrl firmada CONTIENE el ref como substring; ambos se preservan '
      'sin cruzarse',
      () {
        // Caso diseñado para FALLAR si el mapper intercambia ref<->url: la url
        // es un superset firmado del ref, así que swap haría que ambos asserts
        // fallaran (no sólo uno).
        const ref = 'tenant/org/media/abc.png';
        const url =
            'https://cdn.ataulfo.app/tenant/org/media/abc.png?sig=deadbeef&exp=9999';
        final resp = MediaAssetResp.fromJson(<String, dynamic>{
          'ref': ref,
          'url': url,
          'filename': 'abc.png',
          'content_type': 'image/png',
          'size': 2048,
          'created_at': '2026-05-30T12:00:00Z',
        });

        final asset = MediaMapper.assetRespToEntity(resp);

        // ref es BARE: sin esquema, sin query de firma.
        expect(asset.ref, ref);
        expect(asset.ref, isNot(contains('https://')));
        expect(asset.ref, isNot(contains('?sig=')));
        // previewUrl es la url firmada completa (efímera, sólo display).
        expect(asset.previewUrl, url);
      },
    );

    test('url ausente (omitempty) => previewUrl null, ref presente', () {
      final resp = MediaAssetResp.fromJson(<String, dynamic>{
        'ref': 'tenant/org/media/x.png',
        'filename': 'x.png',
        'content_type': 'image/png',
        'size': 10,
        'created_at': '2026-05-30T12:00:00Z',
      });

      final asset = MediaMapper.assetRespToEntity(resp);

      expect(asset.previewUrl, isNull);
      expect(asset.ref, 'tenant/org/media/x.png');
    });

    test('created_at ISO-8601 => DateTime (UTC del wire)', () {
      final resp = MediaAssetResp.fromJson(<String, dynamic>{
        'ref': 'r',
        'filename': 'f',
        'content_type': 'image/png',
        'size': 1,
        'created_at': '2026-05-30T12:34:56Z',
      });

      final asset = MediaMapper.assetRespToEntity(resp);

      expect(asset.createdAt, DateTime.utc(2026, 5, 30, 12, 34, 56));
      expect(asset.filename, 'f');
      expect(asset.contentType, 'image/png');
      expect(asset.size, 1);
    });
  });

  group('MediaMapper.uploadRespToEntity (ref BARE vs previewUrl)', () {
    test('ref + url firmada que contiene el ref => sin cruce', () {
      const ref = 'tenant/org/media/up.png';
      const url =
          'https://cdn.ataulfo.app/tenant/org/media/up.png?sig=cafe&exp=1';
      final resp = UploadResp.fromJson(<String, dynamic>{
        'ref': ref,
        'url': url,
      });

      final uploaded = MediaMapper.uploadRespToEntity(resp);

      expect(uploaded.ref, ref);
      expect(uploaded.ref, isNot(contains('https://')));
      expect(uploaded.previewUrl, url);
    });

    test('url ausente (omitempty) => previewUrl null', () {
      final resp = UploadResp.fromJson(<String, dynamic>{'ref': 'bare/ref'});

      final uploaded = MediaMapper.uploadRespToEntity(resp);

      expect(uploaded.ref, 'bare/ref');
      expect(uploaded.previewUrl, isNull);
    });
  });
}
