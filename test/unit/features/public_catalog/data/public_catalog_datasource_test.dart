import 'package:ataulfo/features/public_catalog/data/datasources/public_catalog_datasource.dart';
import 'package:ataulfo/features/public_catalog/data/dto/public_catalog_settings_dto.dart';
import 'package:ataulfo/features/public_catalog/domain/failures/public_catalog_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() => registerFallbackValue(Options()));

  late _MockDio dio;
  late DioPublicCatalogDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioPublicCatalogDatasource(dio);
  });

  Response<T> resp<T>(int status, {T? body}) => Response<T>(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
    data: body,
  );

  DioException badResponse(int status, {dynamic data}) => DioException(
    requestOptions: RequestOptions(path: '/x'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/x'),
      statusCode: status,
      data: data,
    ),
    type: DioExceptionType.badResponse,
  );

  void whenGet(Map<String, dynamic>? data, {int status = 200}) {
    when(
      () => dio.get<Map<String, dynamic>>(any()),
    ).thenAnswer((_) async => resp<Map<String, dynamic>>(status, body: data));
  }

  void whenPut(Map<String, dynamic>? data, {int status = 200}) {
    when(
      () => dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
    ).thenAnswer((_) async => resp<Map<String, dynamic>>(status, body: data));
  }

  void whenPutThrows(Object error) {
    when(
      () => dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
    ).thenThrow(error);
  }

  Map<String, dynamic> capturedPutBody() {
    final captured = verify(
      () =>
          dio.put<Map<String, dynamic>>(any(), data: captureAny(named: 'data')),
    ).captured;
    return captured.single as Map<String, dynamic>;
  }

  group('DTO', () {
    test('enabled + slug + url', () {
      final dto = PublicCatalogSettingsDto.fromJson(<String, dynamic>{
        'enabled': true,
        'slug': 'tacos',
        'url': 'https://ataulfo.app/c/tacos',
      });
      expect(dto.enabled, true);
      expect(dto.slug, 'tacos');
      expect(dto.url, 'https://ataulfo.app/c/tacos');
    });

    test('slug/url null (nunca acuñó) ⇒ null', () {
      final dto = PublicCatalogSettingsDto.fromJson(<String, dynamic>{
        'enabled': false,
        'slug': null,
        'url': null,
      });
      expect(dto.enabled, false);
      expect(dto.slug, isNull);
      expect(dto.url, isNull);
    });

    test('enabled ausente o de otro tipo ⇒ FormatException (wire roto)', () {
      expect(
        () => PublicCatalogSettingsDto.fromJson(<String, dynamic>{'slug': 'x'}),
        throwsFormatException,
      );
      expect(
        () => PublicCatalogSettingsDto.fromJson(<String, dynamic>{
          'enabled': 'sí',
        }),
        throwsFormatException,
      );
    });
  });

  group('get', () {
    test('200 ⇒ settings', () async {
      whenGet(<String, dynamic>{'enabled': true, 'slug': 'tacos', 'url': 'u'});
      final s = await ds.get();
      expect(s.enabled, true);
      expect(s.slug, 'tacos');
    });

    test('403 ⇒ ForbiddenFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any()),
      ).thenThrow(badResponse(403));
      expect(() => ds.get(), throwsA(const PublicCatalogForbiddenFailure()));
    });

    test('timeout ⇒ NetworkFailure', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      expect(() => ds.get(), throwsA(const PublicCatalogNetworkFailure()));
    });
  });

  group('update', () {
    test('slug vacío se OMITE del body (delega en el backend)', () async {
      whenPut(<String, dynamic>{'enabled': true, 'slug': 'auto', 'url': 'u'});
      await ds.update(enabled: true, slug: '');
      expect(capturedPutBody(), <String, dynamic>{'enabled': true});
    });

    test('slug propuesto viaja en el body', () async {
      whenPut(<String, dynamic>{
        'enabled': true,
        'slug': 'mi-tienda',
        'url': 'u',
      });
      final s = await ds.update(enabled: true, slug: 'mi-tienda');
      expect(capturedPutBody(), <String, dynamic>{
        'enabled': true,
        'slug': 'mi-tienda',
      });
      expect(s.slug, 'mi-tienda');
    });

    test('422 ⇒ InvalidSlugFailure', () async {
      whenPutThrows(
        badResponse(422, data: <String, dynamic>{'error': 'invalid_slug'}),
      );
      expect(
        () => ds.update(enabled: true, slug: 'MAYUS'),
        throwsA(const PublicCatalogInvalidSlugFailure()),
      );
    });

    test('409 slug_taken ⇒ SlugTakenFailure', () async {
      whenPutThrows(
        badResponse(409, data: <String, dynamic>{'error': 'slug_taken'}),
      );
      expect(
        () => ds.update(enabled: true, slug: 'ocupado'),
        throwsA(const PublicCatalogSlugTakenFailure()),
      );
    });

    test('500 ⇒ ServerFailure', () async {
      whenPutThrows(badResponse(500));
      expect(
        () => ds.update(enabled: false, slug: ''),
        throwsA(const PublicCatalogServerFailure()),
      );
    });
  });
}
