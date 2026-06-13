import 'package:ataulfo/features/flows/data/datasources/flows_datasource.dart';
import 'package:ataulfo/features/flows/domain/failures/flows_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioFlowsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioFlowsDatasource(dio);
  });

  DioException badResponse(
    int status, {
    String path = '/flows/f1/steps/order',
  }) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('DioFlowsDatasource.reorderSteps', () {
    test('PUT /flows/:id/steps/order con el array completo de ids', () async {
      when(
        () => dio.put<void>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/flows/f1/steps/order'),
          statusCode: 204,
        ),
      );

      await ds.reorderSteps(flowId: 'f1', ids: const ['s3', 's1', 's2']);

      final captured = verify(
        () => dio.put<void>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/flows/f1/steps/order');
      expect(captured[1], {
        'ids': ['s3', 's1', 's2'],
      });
    });

    test(
      '422 → FlowsInvalidReorderFailure (arreglo rompe un condicional)',
      () async {
        when(
          () => dio.put<void>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenThrow(badResponse(422));

        expect(
          () => ds.reorderSteps(flowId: 'f1', ids: const ['s1']),
          throwsA(isA<FlowsInvalidReorderFailure>()),
        );
      },
    );

    test('404 → FlowsNotFoundFailure (flow ajeno/inexistente)', () async {
      when(
        () => dio.put<void>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(badResponse(404));

      expect(
        () => ds.reorderSteps(flowId: 'ghost', ids: const ['s1']),
        throwsA(isA<FlowsNotFoundFailure>()),
      );
    });
  });

  group('DioFlowsDatasource.deleteStep — 409 referenciado', () {
    test(
      '409 → FlowsStepReferencedFailure (destino de un condicional)',
      () async {
        when(
          () => dio.delete<void>(any(), options: any(named: 'options')),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/steps/s1'),
            response: Response<dynamic>(
              requestOptions: RequestOptions(path: '/steps/s1'),
              statusCode: 409,
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        expect(
          () => ds.deleteStep('s1'),
          throwsA(isA<FlowsStepReferencedFailure>()),
        );
      },
    );
  });
}
