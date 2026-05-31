import 'dart:typed_data';

import 'package:ataulfo/features/media/data/datasources/media_datasource.dart';
import 'package:ataulfo/features/media/domain/failures/media_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(FormData());
  });

  late _MockDio dio;
  late DioMediaDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioMediaDatasource(dio);
  });

  Response<Map<String, dynamic>> mapResp(
    String path,
    int status, {
    Map<String, dynamic>? body,
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: path),
    statusCode: status,
    data: body,
  );

  DioException badResponse(String path, int status) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('DioMediaDatasource.upload', () {
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

    test('201 {ref, url} => UploadedMedia(ref bare, previewUrl)', () async {
      when(
        () =>
            dio.post<Map<String, dynamic>>('/upload', data: any(named: 'data')),
      ).thenAnswer(
        (_) async => mapResp(
          '/upload',
          201,
          body: <String, dynamic>{
            'ref': 'tenant/org/media/abc.png',
            'url': 'https://cdn.ataulfo.app/tenant/org/media/abc.png?sig=x',
          },
        ),
      );

      final result = await ds.upload(bytes: bytes, filename: 'abc.png');

      expect(result.ref, 'tenant/org/media/abc.png');
      expect(
        result.previewUrl,
        'https://cdn.ataulfo.app/tenant/org/media/abc.png?sig=x',
      );
    });

    test(
      'manda un FormData con el part "file" y el filename correcto',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(
            '/upload',
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async =>
              mapResp('/upload', 201, body: <String, dynamic>{'ref': 'r'}),
        );

        await ds.upload(bytes: bytes, filename: 'photo.png');

        final captured = verify(
          () => dio.post<Map<String, dynamic>>(
            '/upload',
            data: captureAny(named: 'data'),
          ),
        ).captured;
        final fd = captured.single as FormData;
        expect(fd.files, hasLength(1));
        expect(fd.files.first.key, 'file');
        expect(fd.files.first.value.filename, 'photo.png');
      },
    );

    test('201 con url ausente (omitempty) => previewUrl null', () async {
      when(
        () =>
            dio.post<Map<String, dynamic>>('/upload', data: any(named: 'data')),
      ).thenAnswer(
        (_) async =>
            mapResp('/upload', 201, body: <String, dynamic>{'ref': 'bare/ref'}),
      );

      final result = await ds.upload(bytes: bytes, filename: 'f');

      expect(result.ref, 'bare/ref');
      expect(result.previewUrl, isNull);
    });

    test('413 => MediaTooLargeFailure', () async {
      when(
        () =>
            dio.post<Map<String, dynamic>>('/upload', data: any(named: 'data')),
      ).thenThrow(badResponse('/upload', 413));

      await expectLater(
        ds.upload(bytes: bytes, filename: 'f'),
        throwsA(isA<MediaTooLargeFailure>()),
      );
    });

    test('415 => MediaUnsupportedTypeFailure', () async {
      when(
        () =>
            dio.post<Map<String, dynamic>>('/upload', data: any(named: 'data')),
      ).thenThrow(badResponse('/upload', 415));

      await expectLater(
        ds.upload(bytes: bytes, filename: 'f'),
        throwsA(isA<MediaUnsupportedTypeFailure>()),
      );
    });

    test('400 (form inválido) => UnknownMediaFailure', () async {
      when(
        () =>
            dio.post<Map<String, dynamic>>('/upload', data: any(named: 'data')),
      ).thenThrow(badResponse('/upload', 400));

      await expectLater(
        ds.upload(bytes: bytes, filename: 'f'),
        throwsA(isA<UnknownMediaFailure>()),
      );
    });

    test(
      '401 final (interceptor agotó refresh) => UnknownMediaFailure',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(
            '/upload',
            data: any(named: 'data'),
          ),
        ).thenThrow(badResponse('/upload', 401));

        await expectLater(
          ds.upload(bytes: bytes, filename: 'f'),
          throwsA(isA<UnknownMediaFailure>()),
        );
      },
    );

    test('500 => MediaServerFailure', () async {
      when(
        () =>
            dio.post<Map<String, dynamic>>('/upload', data: any(named: 'data')),
      ).thenThrow(badResponse('/upload', 500));

      await expectLater(
        ds.upload(bytes: bytes, filename: 'f'),
        throwsA(isA<MediaServerFailure>()),
      );
    });

    test('timeout => MediaTimeoutFailure', () async {
      when(
        () =>
            dio.post<Map<String, dynamic>>('/upload', data: any(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/upload'),
          type: DioExceptionType.sendTimeout,
        ),
      );

      await expectLater(
        ds.upload(bytes: bytes, filename: 'f'),
        throwsA(isA<MediaTimeoutFailure>()),
      );
    });

    test('sin conexión => MediaNetworkFailure', () async {
      when(
        () =>
            dio.post<Map<String, dynamic>>('/upload', data: any(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/upload'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        ds.upload(bytes: bytes, filename: 'f'),
        throwsA(isA<MediaNetworkFailure>()),
      );
    });

    test('body nulo => UnknownMediaFailure', () async {
      when(
        () =>
            dio.post<Map<String, dynamic>>('/upload', data: any(named: 'data')),
      ).thenAnswer((_) async => mapResp('/upload', 201, body: null));

      await expectLater(
        ds.upload(bytes: bytes, filename: 'f'),
        throwsA(isA<UnknownMediaFailure>()),
      );
    });

    test('body malformado (ref ausente) => UnknownMediaFailure', () async {
      when(
        () =>
            dio.post<Map<String, dynamic>>('/upload', data: any(named: 'data')),
      ).thenAnswer(
        (_) async =>
            mapResp('/upload', 201, body: <String, dynamic>{'url': 'sin-ref'}),
      );

      await expectLater(
        ds.upload(bytes: bytes, filename: 'f'),
        throwsA(isA<UnknownMediaFailure>()),
      );
    });
  });

  group('DioMediaDatasource.listAssets', () {
    Map<String, dynamic> assetJson() => <String, dynamic>{
      'ref': 'tenant/org/media/a.png',
      'url': 'https://cdn/a.png?sig=z',
      'filename': 'a.png',
      'content_type': 'image/png',
      'size': 7,
      'created_at': '2026-05-30T12:00:00Z',
    };

    test('200 envelope => MediaPage con assets + nextCursor', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/media-assets',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => mapResp(
          '/media-assets',
          200,
          body: <String, dynamic>{
            'assets': <dynamic>[assetJson()],
            'next_cursor': 'next-opaque',
          },
        ),
      );

      final page = await ds.listAssets();

      expect(page.assets, hasLength(1));
      expect(page.assets.first.ref, 'tenant/org/media/a.png');
      expect(page.assets.first.previewUrl, 'https://cdn/a.png?sig=z');
      expect(page.nextCursor, 'next-opaque');
    });

    test(
      'next_cursor vacío => MediaPage.nextCursor vacío (sin más páginas)',
      () async {
        when(
          () => dio.get<Map<String, dynamic>>(
            '/media-assets',
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer(
          (_) async => mapResp(
            '/media-assets',
            200,
            body: <String, dynamic>{'assets': <dynamic>[], 'next_cursor': ''},
          ),
        );

        final page = await ds.listAssets();

        expect(page.assets, isEmpty);
        expect(page.nextCursor, '');
      },
    );

    test('cursor + limit provistos => query params correctos', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/media-assets',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => mapResp(
          '/media-assets',
          200,
          body: <String, dynamic>{'assets': <dynamic>[], 'next_cursor': ''},
        ),
      );

      await ds.listAssets(cursor: 'abc', limit: 20);

      final captured = verify(
        () => dio.get<Map<String, dynamic>>(
          '/media-assets',
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured;
      expect(captured.single, <String, dynamic>{'cursor': 'abc', 'limit': 20});
    });

    test('type provisto => ?type= en el query (picker por tipo)', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/media-assets',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => mapResp(
          '/media-assets',
          200,
          body: <String, dynamic>{'assets': <dynamic>[], 'next_cursor': ''},
        ),
      );

      await ds.listAssets(type: 'video');

      final captured = verify(
        () => dio.get<Map<String, dynamic>>(
          '/media-assets',
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured;
      expect(captured.single, <String, dynamic>{'type': 'video'});
    });

    test(
      'cursor/limit omitidos => query params vacíos (sin claves null)',
      () async {
        when(
          () => dio.get<Map<String, dynamic>>(
            '/media-assets',
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer(
          (_) async => mapResp(
            '/media-assets',
            200,
            body: <String, dynamic>{'assets': <dynamic>[], 'next_cursor': ''},
          ),
        );

        await ds.listAssets();

        final captured = verify(
          () => dio.get<Map<String, dynamic>>(
            '/media-assets',
            queryParameters: captureAny(named: 'queryParameters'),
          ),
        ).captured;
        expect(captured.single, <String, dynamic>{});
      },
    );

    test('400 (cursor corrupto) => UnknownMediaFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/media-assets',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(badResponse('/media-assets', 400));

      await expectLater(
        ds.listAssets(cursor: 'bad'),
        throwsA(isA<UnknownMediaFailure>()),
      );
    });

    test('403 => MediaForbiddenFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/media-assets',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(badResponse('/media-assets', 403));

      await expectLater(ds.listAssets(), throwsA(isA<MediaForbiddenFailure>()));
    });

    test('404 => MediaNotFoundFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/media-assets',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(badResponse('/media-assets', 404));

      await expectLater(ds.listAssets(), throwsA(isA<MediaNotFoundFailure>()));
    });

    test('500 => MediaServerFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/media-assets',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(badResponse('/media-assets', 500));

      await expectLater(ds.listAssets(), throwsA(isA<MediaServerFailure>()));
    });

    test('timeout => MediaTimeoutFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/media-assets',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/media-assets'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      await expectLater(ds.listAssets(), throwsA(isA<MediaTimeoutFailure>()));
    });

    test(
      'body malformado (next_cursor ausente) => UnknownMediaFailure',
      () async {
        when(
          () => dio.get<Map<String, dynamic>>(
            '/media-assets',
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer(
          (_) async => mapResp(
            '/media-assets',
            200,
            body: <String, dynamic>{'assets': <dynamic>[]},
          ),
        );

        await expectLater(ds.listAssets(), throwsA(isA<UnknownMediaFailure>()));
      },
    );

    test('body nulo => UnknownMediaFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/media-assets',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => mapResp('/media-assets', 200, body: null));

      await expectLater(ds.listAssets(), throwsA(isA<UnknownMediaFailure>()));
    });
  });
}
