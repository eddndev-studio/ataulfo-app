import 'package:ataulfo/features/labels/data/datasources/labels_datasource.dart';
import 'package:ataulfo/features/labels/domain/failures/labels_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(<String, dynamic>{});
  });

  late _MockDio dio;
  late DioLabelsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioLabelsDatasource(dio);
  });

  Response<Map<String, dynamic>> okLabel(int status) =>
      Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/labels'),
        statusCode: status,
        data: <String, dynamic>{
          'id': 'l-1',
          'name': 'VIP',
          'color': '#7c3aed',
          'description': 'Cliente prioritario',
        },
      );

  DioException bad(int status, {String path = '/labels'}) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('createLabel', () {
    test('POST /labels {name,color,description} → Label', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => okLabel(201));

      final created = await ds.createLabel(
        name: 'VIP',
        color: '#7C3AED',
        description: 'Cliente prioritario',
      );

      expect(created.id, 'l-1');
      expect(created.name, 'VIP');
      expect(created.color, '#7c3aed');
      expect(created.description, 'Cliente prioritario');

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/labels');
      expect(captured[1], <String, dynamic>{
        'name': 'VIP',
        'color': '#7C3AED',
        'description': 'Cliente prioritario',
      });
    });

    test('422→Validation, 409→DuplicateName, 403→Forbidden', () async {
      Future<void> expectMaps(int status, Matcher m) async {
        when(
          () => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenThrow(bad(status));
        await expectLater(
          () => ds.createLabel(name: 'x', color: '#000000', description: ''),
          throwsA(m),
        );
      }

      await expectMaps(422, isA<LabelsValidationFailure>());
      await expectMaps(409, isA<LabelsDuplicateNameFailure>());
      await expectMaps(403, isA<LabelsForbiddenFailure>());
    });

    test('5xx→Server, connectionError→Network, timeout→Timeout', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(503));
      await expectLater(
        () => ds.createLabel(name: 'x', color: '#000000', description: ''),
        throwsA(isA<LabelsServerFailure>()),
      );

      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/labels'),
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        () => ds.createLabel(name: 'x', color: '#000000', description: ''),
        throwsA(isA<LabelsNetworkFailure>()),
      );

      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/labels'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await expectLater(
        () => ds.createLabel(name: 'x', color: '#000000', description: ''),
        throwsA(isA<LabelsTimeoutFailure>()),
      );
    });
  });

  group('updateLabel', () {
    test('PUT /labels/{id} {name,color,description} → Label', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => okLabel(200));

      final updated = await ds.updateLabel(
        id: 'l-1',
        name: 'VIP',
        color: '#7C3AED',
        description: 'Cliente prioritario',
      );
      expect(updated.id, 'l-1');

      final captured = verify(
        () => dio.put<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/labels/l-1');
      expect((captured[1] as Map)['name'], 'VIP');
    });

    test('404→NotFound, 409→DuplicateName', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(404, path: '/labels/l-1'));
      await expectLater(
        () => ds.updateLabel(
          id: 'l-1',
          name: 'x',
          color: '#000000',
          description: '',
        ),
        throwsA(isA<LabelsNotFoundFailure>()),
      );

      when(
        () => dio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(409, path: '/labels/l-1'));
      await expectLater(
        () => ds.updateLabel(
          id: 'l-1',
          name: 'x',
          color: '#000000',
          description: '',
        ),
        throwsA(isA<LabelsDuplicateNameFailure>()),
      );
    });
  });

  group('deleteLabel', () {
    test('DELETE /labels/{id} → 204', () async {
      when(
        () => dio.delete<void>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/labels/l-1'),
          statusCode: 204,
        ),
      );

      await ds.deleteLabel(id: 'l-1');

      final captured = verify(
        () => dio.delete<void>(captureAny(), options: any(named: 'options')),
      ).captured;
      expect(captured.single, '/labels/l-1');
    });

    test('404→NotFound, 5xx→Server', () async {
      when(
        () => dio.delete<void>(any(), options: any(named: 'options')),
      ).thenThrow(bad(404, path: '/labels/l-1'));
      await expectLater(
        () => ds.deleteLabel(id: 'l-1'),
        throwsA(isA<LabelsNotFoundFailure>()),
      );

      when(
        () => dio.delete<void>(any(), options: any(named: 'options')),
      ).thenThrow(bad(500, path: '/labels/l-1'));
      await expectLater(
        () => ds.deleteLabel(id: 'l-1'),
        throwsA(isA<LabelsServerFailure>()),
      );
    });
  });
}
