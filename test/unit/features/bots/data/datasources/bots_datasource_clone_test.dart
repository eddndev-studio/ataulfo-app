import 'package:ataulfo/features/bots/data/datasources/bots_datasource.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  late _MockDio dio;
  late DioBotsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioBotsDatasource(dio);
  });

  Map<String, dynamic> cloneJson() => <String, dynamic>{
    'id': 'b2',
    'org_id': 'o1',
    'template_id': 't1',
    'name': 'Soporte (copia)',
    'channel': 'WA_UNOFFICIAL',
    'identifier': null,
    'version': 0,
    'paused': false,
    'ai_disabled': false,
  };

  Response<Map<String, dynamic>> ok() => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/bots/b1/clone'),
    statusCode: 201,
    data: cloneJson(),
  );

  DioException bad(int status) => DioException(
    requestOptions: RequestOptions(path: '/bots/b1/clone'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/bots/b1/clone'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('DioBotsDatasource.clone', () {
    test('POST /bots/:id/clone {name} → Bot con id NUEVO', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => ok());

      final clone = await ds.clone(id: 'b1', name: 'Soporte (copia)');

      expect(clone.id, 'b2'); // id distinto del origen
      expect(clone.templateId, 't1');

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/bots/b1/clone');
      expect(captured[1], <String, dynamic>{'name': 'Soporte (copia)'});
    });

    test('422 → BotsInvalidCreateFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(bad(422));
      await expectLater(
        ds.clone(id: 'b1', name: ''),
        throwsA(isA<BotsInvalidCreateFailure>()),
      );
    });

    test('404 (bot origen) → BotsNotFoundFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(bad(404));
      await expectLater(
        ds.clone(id: 'b1', name: 'x'),
        throwsA(isA<BotsNotFoundFailure>()),
      );
    });

    test('409 (sin org activa) → UnknownBotsFailure (NO conflicto)', () async {
      // El clone no usa CAS de versión: su 409 es no-active-org, no conflicto.
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(bad(409));
      await expectLater(
        ds.clone(id: 'b1', name: 'x'),
        throwsA(isA<UnknownBotsFailure>()),
      );
    });

    test('5xx → BotsServerFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(bad(500));
      await expectLater(
        ds.clone(id: 'b1', name: 'x'),
        throwsA(isA<BotsServerFailure>()),
      );
    });

    test('body nulo → UnknownBotsFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/bots/b1/clone'),
          statusCode: 201,
        ),
      );
      await expectLater(
        ds.clone(id: 'b1', name: 'x'),
        throwsA(isA<UnknownBotsFailure>()),
      );
    });
  });
}
