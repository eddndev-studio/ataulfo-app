import 'package:ataulfo/features/product_catalog/data/datasources/composition_datasource.dart';
import 'package:ataulfo/features/product_catalog/domain/entities/composition_job.dart';
import 'package:ataulfo/features/product_catalog/domain/failures/composition_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> _jobJson({String id = 'j1', String status = 'QUEUED'}) =>
    <String, dynamic>{
      'id': id,
      'preset': 'estudio-blanco',
      'model': '',
      'status': status,
      'resultMediaRef': status == 'DONE' ? 'tenant/org/media/out.png' : '',
      'errorNote': status == 'FAILED' ? 'la foto no se pudo recortar' : '',
      'createdAt': '2026-07-08T10:00:00Z',
    };

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioCompositionDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioCompositionDatasource(dio);
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

  DioException byType(DioExceptionType type) => DioException(
    requestOptions: RequestOptions(path: '/x'),
    type: type,
  );

  void whenPost(Map<String, dynamic>? data, {int status = 202}) {
    when(
      () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
    ).thenAnswer((_) async => resp<Map<String, dynamic>>(status, body: data));
  }

  void whenPostThrows(Object error) {
    when(
      () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
    ).thenThrow(error);
  }

  (String, Map<String, dynamic>?) capturedPost() {
    final captured = verify(
      () => dio.post<Map<String, dynamic>>(
        captureAny(),
        data: captureAny(named: 'data'),
      ),
    ).captured;
    return (captured[0] as String, captured[1] as Map<String, dynamic>?);
  }

  group('compose', () {
    test('202 ⇒ jobId; calidad estándar NO viaja la clave model', () async {
      whenPost(<String, dynamic>{'jobId': 'j9'});
      final jobId = await ds.compose(productId: 'p1', preset: 'marmol');
      expect(jobId, 'j9');
      final (path, body) = capturedPost();
      expect(path, '/workspace/catalog/products/p1/compose');
      expect(body, <String, dynamic>{'preset': 'marmol'});
    });

    test('premium ⇒ viaja model gemini-3-pro-image', () async {
      whenPost(<String, dynamic>{'jobId': 'j9'});
      await ds.compose(productId: 'p1', preset: 'marmol', premium: true);
      final (_, body) = capturedPost();
      expect(body, <String, dynamic>{
        'preset': 'marmol',
        'model': 'gemini-3-pro-image',
      });
    });

    test('202 sin jobId ⇒ UnknownCompositionFailure (wire roto)', () async {
      whenPost(<String, dynamic>{});
      expect(
        () => ds.compose(productId: 'p1', preset: 'marmol'),
        throwsA(const UnknownCompositionFailure()),
      );
    });

    test('422 ⇒ Rejected con el copy es-MX de cada código', () async {
      const cases = <String, String>{
        'no_source_image':
            'El producto no tiene foto original. Ponle una imagen primero.',
        'invalid_preset': 'Ese fondo no está disponible. Elige otro.',
        'quota_exceeded': 'Alcanzaste el tope de imágenes de tu plan este mes.',
        'model_not_allowed': 'La calidad premium requiere plan Pro o Business.',
        'subscription_inactive': 'Tu suscripción tiene un pago pendiente.',
        'trial_expired': 'Tu periodo de prueba terminó.',
      };
      for (final entry in cases.entries) {
        whenPostThrows(
          badResponse(422, data: <String, dynamic>{'error': entry.key}),
        );
        await expectLater(
          () => ds.compose(productId: 'p1', preset: 'marmol'),
          throwsA(CompositionRejectedFailure(entry.value)),
          reason: entry.key,
        );
      }
    });

    test('422 con código desconocido ⇒ Rejected sin mensaje (jamás el código '
        'crudo)', () async {
      whenPostThrows(
        badResponse(422, data: <String, dynamic>{'error': 'flux_inverso'}),
      );
      expect(
        () => ds.compose(productId: 'p1', preset: 'marmol'),
        throwsA(const CompositionRejectedFailure()),
      );
    });

    test('503 ⇒ Unavailable; 404 ⇒ NotFound; 500 ⇒ Server', () async {
      whenPostThrows(badResponse(503));
      expect(
        () => ds.compose(productId: 'p1', preset: 'marmol'),
        throwsA(const CompositionUnavailableFailure()),
      );
      whenPostThrows(badResponse(404));
      expect(
        () => ds.compose(productId: 'p1', preset: 'marmol'),
        throwsA(const CompositionNotFoundFailure()),
      );
      whenPostThrows(badResponse(500));
      expect(
        () => ds.compose(productId: 'p1', preset: 'marmol'),
        throwsA(const CompositionServerFailure()),
      );
    });

    test('errores de transporte ⇒ Network/Timeout', () async {
      whenPostThrows(byType(DioExceptionType.connectionError));
      expect(
        () => ds.compose(productId: 'p1', preset: 'marmol'),
        throwsA(const CompositionNetworkFailure()),
      );
      whenPostThrows(byType(DioExceptionType.receiveTimeout));
      expect(
        () => ds.compose(productId: 'p1', preset: 'marmol'),
        throwsA(const CompositionTimeoutFailure()),
      );
    });
  });

  group('listJobs', () {
    void whenGet(Map<String, dynamic>? data) {
      when(
        () => dio.get<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => resp<Map<String, dynamic>>(200, body: data));
    }

    test(
      '200 ⇒ jobs mapeados en el orden del wire (recientes primero)',
      () async {
        whenGet(<String, dynamic>{
          'jobs': <Map<String, dynamic>>[
            _jobJson(id: 'j2', status: 'RUNNING'),
            _jobJson(id: 'j1', status: 'DONE'),
          ],
        });
        final jobs = await ds.listJobs('p1');
        expect(jobs.map((j) => j.id), <String>['j2', 'j1']);
        expect(jobs.first.status, CompositionStatus.running);
        expect(jobs.last.resultMediaRef, 'tenant/org/media/out.png');
        final path = verify(
          () => dio.get<Map<String, dynamic>>(captureAny()),
        ).captured.single;
        expect(path, '/workspace/catalog/products/p1/compositions');
      },
    );

    test('lista vacía ⇒ []', () async {
      whenGet(<String, dynamic>{'jobs': <Map<String, dynamic>>[]});
      expect(await ds.listJobs('p1'), isEmpty);
    });

    test('body nulo o job malformado ⇒ Unknown (wire roto)', () async {
      whenGet(null);
      expect(
        () => ds.listJobs('p1'),
        throwsA(const UnknownCompositionFailure()),
      );
      whenGet(<String, dynamic>{
        'jobs': <Map<String, dynamic>>[_jobJson()..remove('status')],
      });
      expect(
        () => ds.listJobs('p1'),
        throwsA(const UnknownCompositionFailure()),
      );
    });

    test('404 ⇒ NotFound', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any()),
      ).thenThrow(badResponse(404));
      expect(
        () => ds.listJobs('p1'),
        throwsA(const CompositionNotFoundFailure()),
      );
    });
  });

  group('accept', () {
    test('204 ⇒ completa y pega al path del job', () async {
      whenPost(null, status: 204);
      await ds.accept('j1');
      final (path, body) = capturedPost();
      expect(path, '/workspace/catalog/compositions/j1/accept');
      expect(body, isNull);
    });

    test('409 not_done ⇒ Conflict con copy', () async {
      whenPostThrows(
        badResponse(409, data: <String, dynamic>{'error': 'not_done'}),
      );
      expect(
        () => ds.accept('j1'),
        throwsA(
          const CompositionConflictFailure(
            'Todavía no está lista; espera el resultado.',
          ),
        ),
      );
    });

    test('422 media_not_found ⇒ Rejected con copy', () async {
      whenPostThrows(
        badResponse(422, data: <String, dynamic>{'error': 'media_not_found'}),
      );
      expect(
        () => ds.accept('j1'),
        throwsA(
          const CompositionRejectedFailure(
            'La imagen ya no está en la galería.',
          ),
        ),
      );
    });

    test('404 ⇒ NotFound', () async {
      whenPostThrows(badResponse(404));
      expect(
        () => ds.accept('j1'),
        throwsA(const CompositionNotFoundFailure()),
      );
    });
  });

  group('discard', () {
    test('204 ⇒ completa y pega al path del job', () async {
      whenPost(null, status: 204);
      await ds.discard('j1');
      final (path, _) = capturedPost();
      expect(path, '/workspace/catalog/compositions/j1/discard');
    });

    test('409 in_flight / media_in_use ⇒ Conflict con su copy', () async {
      whenPostThrows(
        badResponse(409, data: <String, dynamic>{'error': 'in_flight'}),
      );
      expect(
        () => ds.discard('j1'),
        throwsA(
          const CompositionConflictFailure(
            'Todavía se está creando; espera el resultado.',
          ),
        ),
      );
      whenPostThrows(
        badResponse(409, data: <String, dynamic>{'error': 'media_in_use'}),
      );
      expect(
        () => ds.discard('j1'),
        throwsA(
          const CompositionConflictFailure(
            'El producto usa esta imagen; cámbiala antes de descartarla.',
          ),
        ),
      );
    });

    test('409 con código desconocido ⇒ Conflict sin mensaje', () async {
      whenPostThrows(badResponse(409, data: <String, dynamic>{'error': 'x'}));
      expect(
        () => ds.discard('j1'),
        throwsA(const CompositionConflictFailure()),
      );
    });

    test('404 ⇒ NotFound', () async {
      whenPostThrows(badResponse(404));
      expect(
        () => ds.discard('j1'),
        throwsA(const CompositionNotFoundFailure()),
      );
    });
  });
}
