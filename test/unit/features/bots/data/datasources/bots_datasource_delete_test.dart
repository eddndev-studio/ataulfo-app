import 'package:ataulfo/features/bots/data/datasources/bots_datasource.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioBotsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioBotsDatasource(dio);
  });

  DioException bad(int status) => DioException(
    requestOptions: RequestOptions(path: '/bots/b1'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/bots/b1'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('DioBotsDatasource.delete', () {
    test('DELETE /bots/:id → 204 sin body', () async {
      when(() => dio.delete<void>(any())).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/bots/b1'),
          statusCode: 204,
        ),
      );

      await ds.delete('b1');

      final captured = verify(() => dio.delete<void>(captureAny())).captured;
      expect(captured.single, '/bots/b1');
    });

    test('404 → BotsNotFoundFailure', () async {
      when(() => dio.delete<void>(any())).thenThrow(bad(404));
      await expectLater(
        ds.delete('b1'),
        throwsA(isA<BotsNotFoundFailure>()),
      );
    });

    test('403 → BotsForbiddenFailure', () async {
      when(() => dio.delete<void>(any())).thenThrow(bad(403));
      await expectLater(
        ds.delete('b1'),
        throwsA(isA<BotsForbiddenFailure>()),
      );
    });

    test('409 (sin org activa) → UnknownBotsFailure (NO conflicto)', () async {
      when(() => dio.delete<void>(any())).thenThrow(bad(409));
      await expectLater(
        ds.delete('b1'),
        throwsA(isA<UnknownBotsFailure>()),
      );
    });

    test('5xx → BotsServerFailure', () async {
      when(() => dio.delete<void>(any())).thenThrow(bad(500));
      await expectLater(
        ds.delete('b1'),
        throwsA(isA<BotsServerFailure>()),
      );
    });

    test('sin conexión → BotsNetworkFailure', () async {
      when(() => dio.delete<void>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/bots/b1'),
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        ds.delete('b1'),
        throwsA(isA<BotsNetworkFailure>()),
      );
    });
  });
}
