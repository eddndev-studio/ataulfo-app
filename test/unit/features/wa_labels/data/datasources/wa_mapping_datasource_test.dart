import 'package:ataulfo/features/wa_labels/data/datasources/wa_mapping_datasource.dart';
import 'package:ataulfo/features/wa_labels/domain/failures/wa_labels_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioWaMappingDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioWaMappingDatasource(dio);
  });

  DioException bad(int status, {String path = '/x'}) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('listMappings', () {
    test('GET /bots/b1/wa-label-mappings → List<WaLabelMapping>', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/bots/b1/wa-label-mappings'),
          statusCode: 200,
          data: <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'waLabelId': '1000', 'labelId': 'uuid-vip'},
            ],
          },
        ),
      );
      final ms = await ds.listMappings('b1');
      expect(ms.single.labelId, 'uuid-vip');
      final captured = verify(
        () => dio.get<Map<String, dynamic>>(
          captureAny(),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured.single, '/bots/b1/wa-label-mappings');
    });
  });

  group('setMapping', () {
    test('PUT .../mapping body {labelId} → 200 WaLabelMapping', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(
            path: '/bots/b1/wa-labels/1000/mapping',
          ),
          statusCode: 200,
          data: <String, dynamic>{'waLabelId': '1000', 'labelId': 'uuid-vip'},
        ),
      );

      final m = await ds.setMapping(
        botId: 'b1',
        waLabelId: '1000',
        labelId: 'uuid-vip',
      );
      expect(m.labelId, 'uuid-vip');

      final captured = verify(
        () => dio.put<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/bots/b1/wa-labels/1000/mapping');
      expect((captured[1] as Map<String, dynamic>)['labelId'], 'uuid-vip');
    });

    test('422→Invalid (label inexistente en la org)', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(422, path: '/bots/b1/wa-labels/1000/mapping'));
      await expectLater(
        () => ds.setMapping(botId: 'b1', waLabelId: '1000', labelId: 'ghost'),
        throwsA(isA<WaLabelsInvalidFailure>()),
      );
    });

    test('el mapeo NO empuja a WA: un 502 no se traduce a Upstream', () async {
      // El set/clear de mapeo no toca WhatsApp; un 5xx es del backend → Server,
      // no Upstream (no hay push aguas arriba que falle).
      when(
        () => dio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(502, path: '/bots/b1/wa-labels/1000/mapping'));
      await expectLater(
        () => ds.setMapping(botId: 'b1', waLabelId: '1000', labelId: 'x'),
        throwsA(isA<WaLabelsServerFailure>()),
      );
    });
  });

  group('deleteMapping', () {
    test('DELETE .../mapping 200 sin body → completa (idempotente)', () async {
      when(
        () => dio.delete<void>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(
            path: '/bots/b1/wa-labels/1000/mapping',
          ),
          statusCode: 200,
        ),
      );
      await ds.deleteMapping(botId: 'b1', waLabelId: '1000');
      final captured = verify(
        () => dio.delete<void>(captureAny(), options: any(named: 'options')),
      ).captured;
      expect(captured.single, '/bots/b1/wa-labels/1000/mapping');
    });

    test('404→NotFound (bot ajeno)', () async {
      when(
        () => dio.delete<void>(any(), options: any(named: 'options')),
      ).thenThrow(bad(404, path: '/bots/b1/wa-labels/1000/mapping'));
      await expectLater(
        () => ds.deleteMapping(botId: 'b1', waLabelId: '1000'),
        throwsA(isA<WaLabelsNotFoundFailure>()),
      );
    });
  });
}
