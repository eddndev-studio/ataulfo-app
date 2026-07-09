import 'package:ataulfo/features/public_catalog/data/datasources/public_catalog_datasource.dart';
import 'package:ataulfo/features/public_catalog/data/dto/public_catalog_settings_dto.dart';
import 'package:ataulfo/features/public_catalog/domain/entities/catalog_appearance.dart';
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
    test('enabled + slug + url + design + accent', () {
      final dto = PublicCatalogSettingsDto.fromJson(<String, dynamic>{
        'enabled': true,
        'slug': 'tacos',
        'url': 'https://ataulfo.app/c/tacos',
        'design': 'mostrador',
        'accent': 'vino',
      });
      expect(dto.enabled, true);
      expect(dto.slug, 'tacos');
      expect(dto.url, 'https://ataulfo.app/c/tacos');
      expect(dto.design, CatalogDesign.mostrador);
      expect(dto.accent, CatalogAccent.vino);
    });

    test('slug/url null (nunca acuñó) ⇒ null', () {
      final dto = PublicCatalogSettingsDto.fromJson(<String, dynamic>{
        'enabled': false,
        'slug': null,
        'url': null,
        'design': 'membrete',
        'accent': 'bosque',
      });
      expect(dto.enabled, false);
      expect(dto.slug, isNull);
      expect(dto.url, isNull);
      expect(dto.design, CatalogDesign.membrete);
      expect(dto.accent, CatalogAccent.bosque);
    });

    test('design/accent ausentes ⇒ defaults carta/mango (fail-open)', () {
      // Backend viejo aún no manda los campos: NO es wire roto.
      final dto = PublicCatalogSettingsDto.fromJson(<String, dynamic>{
        'enabled': true,
        'slug': 'x',
        'url': 'u',
      });
      expect(dto.design, CatalogDesign.carta);
      expect(dto.accent, CatalogAccent.mango);
    });

    test('design/accent desconocidos o no-string ⇒ defaults (fail-open)', () {
      final unknown = PublicCatalogSettingsDto.fromJson(<String, dynamic>{
        'enabled': true,
        'slug': null,
        'url': null,
        'design': 'futurista',
        'accent': 'neon',
      });
      expect(unknown.design, CatalogDesign.carta);
      expect(unknown.accent, CatalogAccent.mango);

      final wrongType = PublicCatalogSettingsDto.fromJson(<String, dynamic>{
        'enabled': true,
        'slug': null,
        'url': null,
        'design': 42,
        'accent': <String, dynamic>{},
      });
      expect(wrongType.design, CatalogDesign.carta);
      expect(wrongType.accent, CatalogAccent.mango);
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
    test('slug vacío se OMITE; design/accent SIEMPRE viajan', () async {
      whenPut(<String, dynamic>{'enabled': true, 'slug': 'auto', 'url': 'u'});
      await ds.update(
        enabled: true,
        slug: '',
        design: CatalogDesign.carta,
        accent: CatalogAccent.mango,
      );
      expect(capturedPutBody(), <String, dynamic>{
        'enabled': true,
        'design': 'carta',
        'accent': 'mango',
      });
    });

    test('slug propuesto y apariencia elegida viajan en el body', () async {
      whenPut(<String, dynamic>{
        'enabled': true,
        'slug': 'mi-tienda',
        'url': 'u',
        'design': 'membrete',
        'accent': 'petroleo',
      });
      final s = await ds.update(
        enabled: true,
        slug: 'mi-tienda',
        design: CatalogDesign.membrete,
        accent: CatalogAccent.petroleo,
      );
      expect(capturedPutBody(), <String, dynamic>{
        'enabled': true,
        'slug': 'mi-tienda',
        'design': 'membrete',
        'accent': 'petroleo',
      });
      expect(s.slug, 'mi-tienda');
      expect(s.design, CatalogDesign.membrete);
      expect(s.accent, CatalogAccent.petroleo);
    });

    test('422 invalid_slug ⇒ InvalidSlugFailure', () async {
      whenPutThrows(
        badResponse(422, data: <String, dynamic>{'error': 'invalid_slug'}),
      );
      expect(
        () => ds.update(
          enabled: true,
          slug: 'MAYUS',
          design: CatalogDesign.carta,
          accent: CatalogAccent.mango,
        ),
        throwsA(const PublicCatalogInvalidSlugFailure()),
      );
    });

    test(
      '422 invalid_design/invalid_accent ⇒ InvalidAppearanceFailure',
      () async {
        for (final code in <String>['invalid_design', 'invalid_accent']) {
          whenPutThrows(
            badResponse(422, data: <String, dynamic>{'error': code}),
          );
          expect(
            () => ds.update(
              enabled: true,
              slug: '',
              design: CatalogDesign.membrete,
              accent: CatalogAccent.vino,
            ),
            throwsA(const PublicCatalogInvalidAppearanceFailure()),
            reason: code,
          );
        }
      },
    );

    test('422 sin code (o code desconocido) ⇒ UnknownFailure', () async {
      whenPutThrows(badResponse(422));
      expect(
        () => ds.update(
          enabled: true,
          slug: 'x',
          design: CatalogDesign.carta,
          accent: CatalogAccent.mango,
        ),
        throwsA(const PublicCatalogUnknownFailure()),
      );
    });

    test('409 slug_taken ⇒ SlugTakenFailure', () async {
      whenPutThrows(
        badResponse(409, data: <String, dynamic>{'error': 'slug_taken'}),
      );
      expect(
        () => ds.update(
          enabled: true,
          slug: 'ocupado',
          design: CatalogDesign.carta,
          accent: CatalogAccent.mango,
        ),
        throwsA(const PublicCatalogSlugTakenFailure()),
      );
    });

    test('500 ⇒ ServerFailure', () async {
      whenPutThrows(badResponse(500));
      expect(
        () => ds.update(
          enabled: false,
          slug: '',
          design: CatalogDesign.carta,
          accent: CatalogAccent.mango,
        ),
        throwsA(const PublicCatalogServerFailure()),
      );
    });
  });
}
