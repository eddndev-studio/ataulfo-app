import 'package:ataulfo/features/messages/data/datasources/messages_datasource.dart';
import 'package:ataulfo/features/messages/domain/failures/messages_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

/// `clearHistory` — DELETE /sessions/:botId/:chatLid/history (S07 RF#10).
/// 204 sin cuerpo; los errores se traducen con el mapa de ESCRITURA (403 RBAC
/// ADMIN+, 404 bot ajeno, 5xx servidor).
void main() {
  late _MockDio dio;
  late DioMessagesDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioMessagesDatasource(dio);
  });

  Response<void> noContent() => Response<void>(
    requestOptions: RequestOptions(path: '/sessions/b1/lid-1/history'),
    statusCode: 204,
  );

  DioException badResponse(int status) => DioException(
    requestOptions: RequestOptions(path: '/sessions/b1/lid-1/history'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/sessions/b1/lid-1/history'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  test('204 → completa sin error', () async {
    when(() => dio.delete<void>(any())).thenAnswer((_) async => noContent());

    await ds.clearHistory('b1', 'lid-1');

    verify(() => dio.delete<void>('/sessions/b1/lid-1/history')).called(1);
  });

  test('chatLid con `@` → segmento percent-encodeado', () async {
    when(() => dio.delete<void>(any())).thenAnswer((_) async => noContent());

    await ds.clearHistory('b1', '123@g.us');

    verify(() => dio.delete<void>('/sessions/b1/123%40g.us/history')).called(1);
  });

  test('403 (rol insuficiente) → MessagesForbiddenFailure', () async {
    when(() => dio.delete<void>(any())).thenThrow(badResponse(403));

    expect(
      () => ds.clearHistory('b1', 'lid-1'),
      throwsA(isA<MessagesForbiddenFailure>()),
    );
  });

  test('404 (bot ajeno) → MessagesNotFoundFailure', () async {
    when(() => dio.delete<void>(any())).thenThrow(badResponse(404));

    expect(
      () => ds.clearHistory('b1', 'lid-1'),
      throwsA(isA<MessagesNotFoundFailure>()),
    );
  });

  test('500 → MessagesServerFailure', () async {
    when(() => dio.delete<void>(any())).thenThrow(badResponse(500));

    expect(
      () => ds.clearHistory('b1', 'lid-1'),
      throwsA(isA<MessagesServerFailure>()),
    );
  });

  test('sin conexión → MessagesNetworkFailure', () async {
    when(() => dio.delete<void>(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/sessions/b1/lid-1/history'),
        type: DioExceptionType.connectionError,
      ),
    );

    expect(
      () => ds.clearHistory('b1', 'lid-1'),
      throwsA(isA<MessagesNetworkFailure>()),
    );
  });
}
