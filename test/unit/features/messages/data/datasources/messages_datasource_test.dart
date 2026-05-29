import 'package:ataulfo/features/messages/data/datasources/messages_datasource.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/domain/failures/messages_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioMessagesDatasource ds;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    dio = _MockDio();
    ds = DioMessagesDatasource(dio);
  });

  Response<Map<String, dynamic>> resp(
    int status, {
    Map<String, dynamic>? body,
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/sessions/b1/lid-1/messages'),
    statusCode: status,
    data: body,
  );

  DioException badResponse(int status) => DioException(
    requestOptions: RequestOptions(path: '/sessions/b1/lid-1/messages'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/sessions/b1/lid-1/messages'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  Map<String, dynamic> msgJson({
    String externalId = 'e1',
    String direction = 'INBOUND',
    String? status,
  }) => <String, dynamic>{
    'externalId': externalId,
    'chatLid': 'lid-1',
    'senderLid': 'alice',
    'kind': 'DM',
    'direction': direction,
    'type': 'text',
    'content': 'hola',
    'timestampMs': 1700,
    'status': ?status,
  };

  void stub(Response<Map<String, dynamic>> r) {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => r);
  }

  void stubThrow(Object e) {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenThrow(e);
  }

  List<dynamic> captured() => verify(
    () => dio.get<Map<String, dynamic>>(
      captureAny(),
      queryParameters: captureAny(named: 'queryParameters'),
    ),
  ).captured;

  group('DioMessagesDatasource.thread', () {
    test('200 {messages, prevCursor} → MessagePage', () async {
      stub(
        resp(
          200,
          body: <String, dynamic>{
            'messages': <dynamic>[
              msgJson(externalId: 'a'),
              msgJson(externalId: 'b', direction: 'OUTBOUND', status: 'SENT'),
            ],
            'prevCursor': '1500:a',
          },
        ),
      );

      final page = await ds.thread('b1', 'lid-1');

      expect(page.messages, hasLength(2));
      expect(page.messages[0].externalId, 'a');
      expect(page.messages[1].direction, MessageDirection.outbound);
      expect(page.messages[1].status, MessageStatus.sent);
      expect(page.prevCursor, '1500:a');
    });

    test(
      '200 hilo vacío {messages: []} → página vacía, sin prevCursor',
      () async {
        stub(resp(200, body: <String, dynamic>{'messages': <dynamic>[]}));
        final page = await ds.thread('b1', 'lid-1');
        expect(page.messages, isEmpty);
        expect(page.prevCursor, isNull);
      },
    );

    test(
      'sin cursor → path /sessions/:bot/:chat/messages, query vacía',
      () async {
        stub(resp(200, body: <String, dynamic>{'messages': <dynamic>[]}));
        await ds.thread('b1', 'lid-1');
        final c = captured();
        expect(c[0], '/sessions/b1/lid-1/messages');
        expect(c[1], <String, dynamic>{});
      },
    );

    test('cursor + limit → viajan como query params', () async {
      stub(resp(200, body: <String, dynamic>{'messages': <dynamic>[]}));
      await ds.thread('b1', 'lid-1', cursor: '200:e2', limit: 30);
      final c = captured();
      expect(c[1], <String, dynamic>{'cursor': '200:e2', 'limit': 30});
    });

    // El chatLid de un grupo lleva `@` (`...@g.us`): debe viajar
    // percent-encodeado en el segmento del path para no romper la ruta ni el
    // matching del ServeMux del backend (que luego lo decodifica).
    test('chatLid con `@` → segmento percent-encodeado', () async {
      stub(resp(200, body: <String, dynamic>{'messages': <dynamic>[]}));
      await ds.thread('b1', '12036@g.us');
      final c = captured();
      expect(c[0], '/sessions/b1/12036%40g.us/messages');
    });

    test('timeout → MessagesTimeoutFailure', () async {
      stubThrow(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await expectLater(
        ds.thread('b1', 'lid-1'),
        throwsA(isA<MessagesTimeoutFailure>()),
      );
    });

    test('sin conexión → MessagesNetworkFailure', () async {
      stubThrow(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        ds.thread('b1', 'lid-1'),
        throwsA(isA<MessagesNetworkFailure>()),
      );
    });

    test('403 → MessagesForbiddenFailure', () async {
      stubThrow(badResponse(403));
      await expectLater(
        ds.thread('b1', 'lid-1'),
        throwsA(isA<MessagesForbiddenFailure>()),
      );
    });

    test('404 (bot ajeno) → MessagesNotFoundFailure', () async {
      stubThrow(badResponse(404));
      await expectLater(
        ds.thread('b1', 'lid-1'),
        throwsA(isA<MessagesNotFoundFailure>()),
      );
    });

    test('500 → MessagesServerFailure', () async {
      stubThrow(badResponse(500));
      await expectLater(
        ds.thread('b1', 'lid-1'),
        throwsA(isA<MessagesServerFailure>()),
      );
    });

    test('409 → UnknownMessagesFailure', () async {
      stubThrow(badResponse(409));
      await expectLater(
        ds.thread('b1', 'lid-1'),
        throwsA(isA<UnknownMessagesFailure>()),
      );
    });

    test('body nulo → UnknownMessagesFailure', () async {
      stub(resp(200));
      await expectLater(
        ds.thread('b1', 'lid-1'),
        throwsA(isA<UnknownMessagesFailure>()),
      );
    });

    test('elemento malformado → UnknownMessagesFailure', () async {
      stub(
        resp(
          200,
          body: <String, dynamic>{
            'messages': <dynamic>[
              <String, dynamic>{'externalId': 'x'},
            ],
          },
        ),
      );
      await expectLater(
        ds.thread('b1', 'lid-1'),
        throwsA(isA<UnknownMessagesFailure>()),
      );
    });

    // kind/direction desconocido (drift de enum) es fail-loud en el mapper
    // (ArgumentError); en el borde de red el datasource lo colapsa a Unknown
    // para que la UI muestre un error visible en vez de un crash sin tipar.
    test('kind desconocido en el wire → UnknownMessagesFailure', () async {
      final bad = msgJson()..['kind'] = 'CHANNEL';
      stub(
        resp(
          200,
          body: <String, dynamic>{
            'messages': <dynamic>[bad],
          },
        ),
      );
      await expectLater(
        ds.thread('b1', 'lid-1'),
        throwsA(isA<UnknownMessagesFailure>()),
      );
    });
  });
}
