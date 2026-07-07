import 'package:ataulfo/features/org_customization/data/datasources/org_branding_datasource.dart';
import 'package:ataulfo/features/org_customization/domain/failures/org_branding_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _resp(int status, Map<String, dynamic> body) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/workspace/organization/branding'),
      statusCode: status,
      data: body,
    );

Response<void> _empty(int status) => Response<void>(
  requestOptions: RequestOptions(path: '/workspace/organization/branding'),
  statusCode: status,
);

DioException _bad(int status) => DioException(
  requestOptions: RequestOptions(path: '/workspace/organization/branding'),
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/workspace/organization/branding'),
    statusCode: status,
  ),
);

DioException _net() => DioException(
  requestOptions: RequestOptions(path: '/workspace/organization/branding'),
  type: DioExceptionType.connectionError,
);

void main() {
  late _MockDio dio;
  late DioOrgBrandingDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioOrgBrandingDatasource(dio);
  });

  group('get', () {
    test('200 completo → entidad con logo y tex de autor', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/workspace/organization/branding'),
      ).thenAnswer(
        (_) async => _resp(200, <String, dynamic>{
          'configured': true,
          'custom_tex': true,
          'has_logo': true,
          'logo_url': 'https://signed/l1',
          'logo_content_type': 'image/png',
        }),
      );

      final b = await ds.get();
      expect(b.configured, isTrue);
      expect(b.customTex, isTrue);
      expect(b.hasLogo, isTrue);
      expect(b.logoUrl, 'https://signed/l1');
      expect(b.logoContentType, 'image/png');
    });

    test('200 sin marca → estado base con defaults', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/workspace/organization/branding'),
      ).thenAnswer(
        (_) async => _resp(200, <String, dynamic>{
          'configured': false,
          'custom_tex': false,
          'has_logo': false,
          'logo_url': '',
          'logo_content_type': '',
        }),
      );

      final b = await ds.get();
      expect(b.configured, isFalse);
      expect(b.hasLogo, isFalse);
      expect(b.logoUrl, isEmpty);
    });

    test('403 → OrgBrandingForbiddenFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/workspace/organization/branding'),
      ).thenThrow(_bad(403));
      await expectLater(ds.get(), throwsA(isA<OrgBrandingForbiddenFailure>()));
    });

    test('red caída → OrgBrandingNetworkFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/workspace/organization/branding'),
      ).thenThrow(_net());
      await expectLater(ds.get(), throwsA(isA<OrgBrandingNetworkFailure>()));
    });
  });

  group('setLogo', () {
    test('204 → envía el ref BARE en snake_case', () async {
      Map<String, dynamic>? captured;
      when(
        () => dio.put<void>(
          '/workspace/organization/branding/logo',
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        captured = inv.namedArguments[#data] as Map<String, dynamic>?;
        return _empty(204);
      });

      await ds.setLogo('tenant/org-1/media/l1.png');
      expect(captured, <String, dynamic>{
        'logo_media_ref': 'tenant/org-1/media/l1.png',
      });
    });

    test(
      '422 (ref ajeno o tipo no incluible) → OrgBrandingInvalidFailure',
      () async {
        when(
          () => dio.put<void>(
            '/workspace/organization/branding/logo',
            data: any(named: 'data'),
          ),
        ).thenThrow(_bad(422));
        await expectLater(
          ds.setLogo('tenant/org-2/media/x.png'),
          throwsA(isA<OrgBrandingInvalidFailure>()),
        );
      },
    );
  });

  group('reset', () {
    test('204 → ok', () async {
      when(
        () => dio.delete<void>('/workspace/organization/branding'),
      ).thenAnswer((_) async => _empty(204));
      await ds.reset();
      verify(
        () => dio.delete<void>('/workspace/organization/branding'),
      ).called(1);
    });

    test('500 → OrgBrandingServerFailure', () async {
      when(
        () => dio.delete<void>('/workspace/organization/branding'),
      ).thenThrow(_bad(500));
      await expectLater(ds.reset(), throwsA(isA<OrgBrandingServerFailure>()));
    });
  });
}
