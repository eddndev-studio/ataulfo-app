import 'package:ataulfo/features/bots/data/datasources/bot_session_datasource.dart';
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
  late DioBotSessionDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioBotSessionDatasource(dio);
  });

  DioException bad(int status, String path) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  Response<void> ok(String path) => Response<void>(
    requestOptions: RequestOptions(path: path),
    statusCode: 204,
  );

  group('clearConversations', () {
    test('POST /bots/:id/clear-conversations → 204', () async {
      when(
        () => dio.post<void>(any()),
      ).thenAnswer((_) async => ok('/bots/b1/clear-conversations'));

      await ds.clearConversations('b1');

      final captured = verify(() => dio.post<void>(captureAny())).captured;
      expect(captured.single, '/bots/b1/clear-conversations');
    });

    test('409 → BotsNotPausedFailure (precondición paused)', () async {
      when(
        () => dio.post<void>(any()),
      ).thenThrow(bad(409, '/bots/b1/clear-conversations'));

      await expectLater(
        ds.clearConversations('b1'),
        throwsA(isA<BotsNotPausedFailure>()),
      );
    });

    test('404 → BotsNotFoundFailure', () async {
      when(
        () => dio.post<void>(any()),
      ).thenThrow(bad(404, '/bots/b1/clear-conversations'));

      await expectLater(
        ds.clearConversations('b1'),
        throwsA(isA<BotsNotFoundFailure>()),
      );
    });

    test('5xx → BotsServerFailure', () async {
      when(
        () => dio.post<void>(any()),
      ).thenThrow(bad(500, '/bots/b1/clear-conversations'));

      await expectLater(
        ds.clearConversations('b1'),
        throwsA(isA<BotsServerFailure>()),
      );
    });
  });

  group('resetSessions', () {
    test('POST /bots/:id/reset-sessions → 204', () async {
      when(
        () => dio.post<void>(any()),
      ).thenAnswer((_) async => ok('/bots/b1/reset-sessions'));

      await ds.resetSessions('b1');

      final captured = verify(() => dio.post<void>(captureAny())).captured;
      expect(captured.single, '/bots/b1/reset-sessions');
    });

    test('409 → BotsNotPausedFailure', () async {
      when(
        () => dio.post<void>(any()),
      ).thenThrow(bad(409, '/bots/b1/reset-sessions'));

      await expectLater(
        ds.resetSessions('b1'),
        throwsA(isA<BotsNotPausedFailure>()),
      );
    });
  });

  group('per-endpoint 409 (regresión): otros verbos de sesión', () {
    test('stopSession con 409 sigue → UnknownBotsFailure (NO NotPaused)', () async {
      when(() => dio.delete<void>(any())).thenThrow(bad(409, '/bots/b1/session'));

      await expectLater(
        ds.stopSession('b1'),
        throwsA(isA<UnknownBotsFailure>()),
      );
    });
  });
}
