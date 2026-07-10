import 'package:ataulfo/features/billing/data/datasources/billing_datasource.dart';
import 'package:ataulfo/features/billing/domain/failures/billing_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioBillingDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioBillingDatasource(dio);
  });

  Response<Map<String, dynamic>> resp(
    int status, {
    Map<String, dynamic>? body,
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/workspace/billing'),
    statusCode: status,
    data: body,
  );

  DioException badResponse(int status) => DioException(
    requestOptions: RequestOptions(path: '/workspace/billing'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/workspace/billing'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  DioException byType(DioExceptionType type) => DioException(
    requestOptions: RequestOptions(path: '/workspace/billing'),
    type: type,
  );

  Map<String, dynamic> body() => <String, dynamic>{
    'plan_code': 'trial',
    'status': 'trialing',
    'credits_used': 12,
    'credit_cap': 800,
    'within_quota': true,
    'quota_exceeded': false,
    'storage_used_mb': 100,
    'storage_quota_mb': 512,
    'eligible_providers': <dynamic>['MINIMAX', 'NEMOTRON'],
    'features': <dynamic>['media_gallery'],
  };

  group('DioBillingDatasource.fetch', () {
    test('200 → Entitlement mapeado a entidad', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/workspace/billing'),
      ).thenAnswer((_) async => resp(200, body: body()));

      final e = await ds.fetch();

      expect(e.planCode, 'trial');
      expect(e.eligibleProviders, <String>{'MINIMAX', 'NEMOTRON'});
      expect(e.creditCap, 800);
      expect(e.storageQuotaMb, 512);
    });

    test('body null → UnknownBillingFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/workspace/billing'),
      ).thenAnswer((_) async => resp(200));

      await expectLater(ds.fetch(), throwsA(isA<UnknownBillingFailure>()));
    });

    test('body malformado (FormatException) → UnknownBillingFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/workspace/billing'),
      ).thenAnswer(
        (_) async => resp(200, body: <String, dynamic>{'plan_code': 'x'}),
      );

      await expectLater(ds.fetch(), throwsA(isA<UnknownBillingFailure>()));
    });

    test('timeouts → BillingTimeoutFailure', () async {
      for (final t in <DioExceptionType>[
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        when(
          () => dio.get<Map<String, dynamic>>('/workspace/billing'),
        ).thenThrow(byType(t));

        await expectLater(ds.fetch(), throwsA(isA<BillingTimeoutFailure>()));
      }
    });

    test('connectionError → BillingNetworkFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/workspace/billing'),
      ).thenThrow(byType(DioExceptionType.connectionError));

      await expectLater(ds.fetch(), throwsA(isA<BillingNetworkFailure>()));
    });

    test('409 → BillingOrgUnresolvedFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/workspace/billing'),
      ).thenThrow(badResponse(409));

      await expectLater(
        ds.fetch(),
        throwsA(isA<BillingOrgUnresolvedFailure>()),
      );
    });

    test('404 → BillingNotFoundFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/workspace/billing'),
      ).thenThrow(badResponse(404));

      await expectLater(ds.fetch(), throwsA(isA<BillingNotFoundFailure>()));
    });

    test('500 → BillingServerFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/workspace/billing'),
      ).thenThrow(badResponse(500));

      await expectLater(ds.fetch(), throwsA(isA<BillingServerFailure>()));
    });

    test('status no contemplado (418) → UnknownBillingFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/workspace/billing'),
      ).thenThrow(badResponse(418));

      await expectLater(ds.fetch(), throwsA(isA<UnknownBillingFailure>()));
    });
  });
}
