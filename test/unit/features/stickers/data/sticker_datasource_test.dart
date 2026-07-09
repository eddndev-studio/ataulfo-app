import 'package:ataulfo/features/stickers/data/datasources/sticker_datasource.dart';
import 'package:ataulfo/features/stickers/domain/entities/sticker_job.dart';
import 'package:ataulfo/features/stickers/domain/failures/sticker_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> _jobJson({String status = 'DONE'}) => <String, dynamic>{
  'id': 's1',
  'motif': 'gracias',
  'model': 'gemini-3.1-flash-lite-image',
  'status': status,
  'resultMediaRef': status == 'DONE' ? 'tenant/org/media/s1.webp' : '',
  'errorNote': status == 'FAILED' ? 'no se pudo recortar' : '',
  'createdAt': '2026-07-08T10:00:00Z',
};

void main() {
  setUpAll(() => registerFallbackValue(Options()));

  late _MockDio dio;
  late DioStickerDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioStickerDatasource(dio);
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

  group('list', () {
    test('200 ⇒ jobs mapeados', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => resp<Map<String, dynamic>>(
          200,
          body: <String, dynamic>{
            'jobs': <dynamic>[_jobJson(), _jobJson(status: 'QUEUED')],
          },
        ),
      );
      final jobs = await ds.list();
      expect(jobs, hasLength(2));
      expect(jobs.first.status, StickerStatus.done);
      expect(jobs.first.resultMediaRef, 'tenant/org/media/s1.webp');
      expect(jobs[1].status, StickerStatus.queued);
    });

    test('timeout ⇒ NetworkFailure', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      expect(() => ds.list(), throwsA(const StickerNetworkFailure()));
    });
  });

  group('generate', () {
    void whenPost(Map<String, dynamic>? data, {int status = 202}) {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => resp<Map<String, dynamic>>(status, body: data));
    }

    void whenPostThrows(Object e) {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(e);
    }

    test('202 ⇒ jobId; el motivo viaja en el body', () async {
      whenPost(<String, dynamic>{'jobId': 's9'});
      final id = await ds.generate('gracias');
      expect(id, 's9');
      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/workspace/stickers/generate');
      expect(captured[1], <String, dynamic>{'motif': 'gracias'});
    });

    test('202 sin jobId ⇒ UnknownFailure (wire roto)', () async {
      whenPost(<String, dynamic>{});
      expect(
        () => ds.generate('gracias'),
        throwsA(const StickerUnknownFailure()),
      );
    });

    test('422 ⇒ Rejected con el copy es-MX del código', () async {
      whenPostThrows(
        badResponse(422, data: <String, dynamic>{'error': 'quota_exceeded'}),
      );
      await expectLater(
        ds.generate('gracias'),
        throwsA(
          isA<StickerRejectedFailure>().having(
            (f) => f.message,
            'message',
            contains('tope de imágenes'),
          ),
        ),
      );
    });

    test('422 con código desconocido ⇒ Rejected message null', () async {
      whenPostThrows(
        badResponse(422, data: <String, dynamic>{'error': 'algo_nuevo'}),
      );
      await expectLater(
        ds.generate('gracias'),
        throwsA(
          isA<StickerRejectedFailure>().having(
            (f) => f.message,
            'message',
            isNull,
          ),
        ),
      );
    });

    test('503 ⇒ UnavailableFailure', () async {
      whenPostThrows(badResponse(503));
      expect(
        () => ds.generate('gracias'),
        throwsA(const StickerUnavailableFailure()),
      );
    });

    test('500 ⇒ ServerFailure', () async {
      whenPostThrows(badResponse(500));
      expect(
        () => ds.generate('gracias'),
        throwsA(const StickerServerFailure()),
      );
    });
  });
}
