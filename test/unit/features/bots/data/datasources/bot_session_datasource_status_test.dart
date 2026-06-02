import 'package:ataulfo/features/bots/data/datasources/bot_session_datasource.dart';
import 'package:ataulfo/features/bots/domain/entities/session_status.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioBotSessionDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioBotSessionDatasource(dio);
  });

  Response<Map<String, dynamic>> ok(Map<String, dynamic> body) =>
      Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/bots/b1/session'),
        statusCode: 200,
        data: body,
      );

  DioException bad(int status) => DioException(
    requestOptions: RequestOptions(path: '/bots/b1/session'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/bots/b1/session'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('getSessionState', () {
    test('PAIRING con qr → SessionStatus(pairing, code)', () async {
      when(() => dio.get<Map<String, dynamic>>('/bots/b1/session')).thenAnswer(
        (_) async => ok(<String, dynamic>{
          'state': 'PAIRING',
          'qr': <String, dynamic>{'code': 'QR-DATA-123'},
        }),
      );

      final s = await ds.getSessionState('b1');

      expect(s.state, SessionState.pairing);
      expect(s.qrCode, 'QR-DATA-123');
    });

    test('CONNECTED sin qr → SessionStatus(connected, null)', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/bots/b1/session'),
      ).thenAnswer((_) async => ok(<String, dynamic>{'state': 'CONNECTED'}));

      final s = await ds.getSessionState('b1');

      expect(s.state, SessionState.connected);
      expect(s.qrCode, isNull);
    });

    test(
      'DISCONNECTED ("not running") → SessionStatus(disconnected, null)',
      () async {
        when(
          () => dio.get<Map<String, dynamic>>('/bots/b1/session'),
        ).thenAnswer(
          (_) async => ok(<String, dynamic>{'state': 'DISCONNECTED'}),
        );

        final s = await ds.getSessionState('b1');
        expect(s.state, SessionState.disconnected);
        expect(s.qrCode, isNull);
      },
    );

    test('CONNECTING y RECONNECTING parsean', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/bots/b1/session'),
      ).thenAnswer((_) async => ok(<String, dynamic>{'state': 'CONNECTING'}));
      expect((await ds.getSessionState('b1')).state, SessionState.connecting);

      when(
        () => dio.get<Map<String, dynamic>>('/bots/b1/session'),
      ).thenAnswer((_) async => ok(<String, dynamic>{'state': 'RECONNECTING'}));
      expect((await ds.getSessionState('b1')).state, SessionState.reconnecting);
    });

    test('state desconocido → UnknownBotsFailure (fail-loud)', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/bots/b1/session'),
      ).thenAnswer((_) async => ok(<String, dynamic>{'state': 'WAT'}));
      await expectLater(
        ds.getSessionState('b1'),
        throwsA(isA<UnknownBotsFailure>()),
      );
    });

    test('403 → BotsForbiddenFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/bots/b1/session'),
      ).thenThrow(bad(403));
      await expectLater(
        ds.getSessionState('b1'),
        throwsA(isA<BotsForbiddenFailure>()),
      );
    });

    test('body nulo → UnknownBotsFailure', () async {
      when(() => dio.get<Map<String, dynamic>>('/bots/b1/session')).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/bots/b1/session'),
          statusCode: 200,
        ),
      );
      await expectLater(
        ds.getSessionState('b1'),
        throwsA(isA<UnknownBotsFailure>()),
      );
    });
  });
}
