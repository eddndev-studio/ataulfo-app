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

  // --- helpers de POST (write path: send / mark-read / react) ---

  Response<Map<String, dynamic>> postResp(
    int status, {
    Map<String, dynamic>? body,
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/p'),
    statusCode: status,
    data: body,
  );

  DioException postBad(int status) => DioException(
    requestOptions: RequestOptions(path: '/p'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/p'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  void stubPost(Response<Map<String, dynamic>> r) {
    when(
      () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
    ).thenAnswer((_) async => r);
  }

  void stubPostThrow(Object e) {
    when(
      () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
    ).thenThrow(e);
  }

  List<dynamic> capturedPost() => verify(
    () => dio.post<Map<String, dynamic>>(
      captureAny(),
      data: captureAny(named: 'data'),
    ),
  ).captured;

  void stubPostVoid(int status) {
    when(() => dio.post<void>(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => Response<void>(
        requestOptions: RequestOptions(path: '/p'),
        statusCode: status,
      ),
    );
  }

  void stubPostVoidThrow(Object e) {
    when(() => dio.post<void>(any(), data: any(named: 'data'))).thenThrow(e);
  }

  List<dynamic> capturedPostVoid() => verify(
    () => dio.post<void>(captureAny(), data: captureAny(named: 'data')),
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

  group('DioMessagesDatasource.send', () {
    Map<String, dynamic> sentMsg() => <String, dynamic>{
      'externalId': 'AG-1',
      'chatLid': 'lid-1',
      'senderLid': 'me',
      'kind': 'DM',
      'direction': 'OUTBOUND',
      'type': 'text',
      'content': 'hola',
      'timestampMs': 1800,
      'status': 'SENT',
    };

    test('200 MessageResp → Message OUTBOUND con wamid', () async {
      stubPost(postResp(200, body: sentMsg()));
      final m = await ds.send(
        'b1',
        'lid-1',
        clientToken: 'ct-1',
        type: 'text',
        content: 'hola',
      );
      expect(m.externalId, 'AG-1');
      expect(m.direction, MessageDirection.outbound);
      expect(m.status, MessageStatus.sent);
    });

    test('path + body de texto (sin mediaRef)', () async {
      stubPost(postResp(200, body: sentMsg()));
      await ds.send(
        'b1',
        'lid-1',
        clientToken: 'ct-1',
        type: 'text',
        content: 'hola',
      );
      final c = capturedPost();
      expect(c[0], '/sessions/b1/lid-1/messages/send');
      expect(c[1], <String, dynamic>{
        'clientToken': 'ct-1',
        'type': 'text',
        'content': 'hola',
      });
    });

    test('imagen → body con mediaRef', () async {
      stubPost(postResp(200, body: sentMsg()..['type'] = 'image'));
      await ds.send(
        'b1',
        'lid-1',
        clientToken: 'ct-2',
        type: 'image',
        content: '',
        mediaRef: 'ref-9',
      );
      final c = capturedPost();
      expect(c[1], <String, dynamic>{
        'clientToken': 'ct-2',
        'type': 'image',
        'content': '',
        'mediaRef': 'ref-9',
      });
    });

    test('respuesta → body con quotedId', () async {
      stubPost(postResp(200, body: sentMsg()));
      await ds.send(
        'b1',
        'lid-1',
        clientToken: 'ct-3',
        type: 'text',
        content: 'respondo',
        quotedId: 'orig-1',
      );
      final c = capturedPost();
      expect(c[1], <String, dynamic>{
        'clientToken': 'ct-3',
        'type': 'text',
        'content': 'respondo',
        'quotedId': 'orig-1',
      });
    });

    test('chatLid con `@` → segmento percent-encodeado', () async {
      stubPost(postResp(200, body: sentMsg()));
      await ds.send(
        'b1',
        '12036@g.us',
        clientToken: 'ct',
        type: 'text',
        content: 'x',
      );
      final c = capturedPost();
      expect(c[0], '/sessions/b1/12036%40g.us/messages/send');
    });

    test('422 → MessagesValidationFailure', () async {
      stubPostThrow(postBad(422));
      await expectLater(
        ds.send('b1', 'lid-1', clientToken: 'ct', type: 'text', content: 'x'),
        throwsA(isA<MessagesValidationFailure>()),
      );
    });

    test('409 → MessagesConflictFailure', () async {
      stubPostThrow(postBad(409));
      await expectLater(
        ds.send('b1', 'lid-1', clientToken: 'ct', type: 'text', content: 'x'),
        throwsA(isA<MessagesConflictFailure>()),
      );
    });

    test('404 (fresh-chat / bot) → MessagesNotFoundFailure', () async {
      stubPostThrow(postBad(404));
      await expectLater(
        ds.send('b1', 'lid-1', clientToken: 'ct', type: 'text', content: 'x'),
        throwsA(isA<MessagesNotFoundFailure>()),
      );
    });

    test('423 (bot pausado) → MessagesBotPausedFailure', () async {
      stubPostThrow(postBad(423));
      await expectLater(
        ds.send('b1', 'lid-1', clientToken: 'ct', type: 'text', content: 'x'),
        throwsA(isA<MessagesBotPausedFailure>()),
      );
    });

    test('503 (bot no corriendo) → MessagesNotConnectedFailure', () async {
      stubPostThrow(postBad(503));
      await expectLater(
        ds.send('b1', 'lid-1', clientToken: 'ct', type: 'text', content: 'x'),
        throwsA(isA<MessagesNotConnectedFailure>()),
      );
    });

    test('502 (wire) → MessagesWireFailure', () async {
      stubPostThrow(postBad(502));
      await expectLater(
        ds.send('b1', 'lid-1', clientToken: 'ct', type: 'text', content: 'x'),
        throwsA(isA<MessagesWireFailure>()),
      );
    });

    test('timeout → MessagesTimeoutFailure', () async {
      stubPostThrow(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.sendTimeout,
        ),
      );
      await expectLater(
        ds.send('b1', 'lid-1', clientToken: 'ct', type: 'text', content: 'x'),
        throwsA(isA<MessagesTimeoutFailure>()),
      );
    });

    test('body nulo → UnknownMessagesFailure', () async {
      stubPost(postResp(200));
      await expectLater(
        ds.send('b1', 'lid-1', clientToken: 'ct', type: 'text', content: 'x'),
        throwsA(isA<UnknownMessagesFailure>()),
      );
    });
  });

  group('DioMessagesDatasource.markRead', () {
    test('200 {markedCount} → conteo', () async {
      stubPost(postResp(200, body: <String, dynamic>{'markedCount': 3}));
      expect(await ds.markRead('b1', 'lid-1'), 3);
    });

    test('sin upToMessageId → body vacío, path mark-read', () async {
      stubPost(postResp(200, body: <String, dynamic>{'markedCount': 0}));
      await ds.markRead('b1', 'lid-1');
      final c = capturedPost();
      expect(c[0], '/sessions/b1/lid-1/mark-read');
      expect(c[1], <String, dynamic>{});
    });

    test('con upToMessageId → viaja en el body', () async {
      stubPost(postResp(200, body: <String, dynamic>{'markedCount': 2}));
      await ds.markRead('b1', 'lid-1', upToMessageId: 'm9');
      final c = capturedPost();
      expect(c[1], <String, dynamic>{'upToMessageId': 'm9'});
    });

    test('404 → MessagesNotFoundFailure', () async {
      stubPostThrow(postBad(404));
      await expectLater(
        ds.markRead('b1', 'lid-1'),
        throwsA(isA<MessagesNotFoundFailure>()),
      );
    });

    test('503 → MessagesNotConnectedFailure', () async {
      stubPostThrow(postBad(503));
      await expectLater(
        ds.markRead('b1', 'lid-1'),
        throwsA(isA<MessagesNotConnectedFailure>()),
      );
    });

    test('markedCount ausente → UnknownMessagesFailure', () async {
      stubPost(postResp(200, body: <String, dynamic>{}));
      await expectLater(
        ds.markRead('b1', 'lid-1'),
        throwsA(isA<UnknownMessagesFailure>()),
      );
    });
  });

  group('DioMessagesDatasource.react', () {
    test('204 → completa; path + body', () async {
      stubPostVoid(204);
      await ds.react('b1', 'lid-1', messageId: 'm1', emoji: '👍');
      final c = capturedPostVoid();
      expect(c[0], '/sessions/b1/lid-1/react');
      expect(c[1], <String, dynamic>{'messageId': 'm1', 'emoji': '👍'});
    });

    test('emoji vacío (remover) permitido', () async {
      stubPostVoid(204);
      await ds.react('b1', 'lid-1', messageId: 'm1', emoji: '');
      final c = capturedPostVoid();
      expect(c[1], <String, dynamic>{'messageId': 'm1', 'emoji': ''});
    });

    test('chatLid con `@` → segmento percent-encodeado', () async {
      stubPostVoid(204);
      await ds.react('b1', '12036@g.us', messageId: 'm1', emoji: '😀');
      final c = capturedPostVoid();
      expect(c[0], '/sessions/b1/12036%40g.us/react');
    });

    test('404 → MessagesNotFoundFailure', () async {
      stubPostVoidThrow(postBad(404));
      await expectLater(
        ds.react('b1', 'lid-1', messageId: 'm1', emoji: 'x'),
        throwsA(isA<MessagesNotFoundFailure>()),
      );
    });

    test('502 → MessagesWireFailure', () async {
      stubPostVoidThrow(postBad(502));
      await expectLater(
        ds.react('b1', 'lid-1', messageId: 'm1', emoji: 'x'),
        throwsA(isA<MessagesWireFailure>()),
      );
    });

    test('422 → MessagesValidationFailure', () async {
      stubPostVoidThrow(postBad(422));
      await expectLater(
        ds.react('b1', 'lid-1', messageId: 'm1', emoji: 'x'),
        throwsA(isA<MessagesValidationFailure>()),
      );
    });
  });

  group('DioMessagesDatasource.editMessage', () {
    test('200 → Message actualizado; path + body', () async {
      stubPost(
        postResp(
          200,
          body: <String, dynamic>{
            ...msgJson(externalId: 'm1', direction: 'OUTBOUND', status: 'SENT'),
            'content': 'precio: \$50',
            'editedAtMs': 1800,
          },
        ),
      );
      final m = await ds.editMessage(
        'b1',
        'lid-1',
        messageId: 'm1',
        newText: 'precio: \$50',
      );
      final c = capturedPost();
      expect(c[0], '/sessions/b1/lid-1/messages/edit');
      expect(c[1], <String, dynamic>{
        'messageId': 'm1',
        'newText': 'precio: \$50',
      });
      expect(m.externalId, 'm1');
      expect(m.content, 'precio: \$50');
      expect(m.editedAtMs, 1800);
    });

    test('chatLid con `@` → segmento percent-encodeado', () async {
      stubPost(
        postResp(
          200,
          body: msgJson(externalId: 'm1', direction: 'OUTBOUND'),
        ),
      );
      await ds.editMessage('b1', '12036@g.us', messageId: 'm1', newText: 'x');
      expect(capturedPost()[0], '/sessions/b1/12036%40g.us/messages/edit');
    });

    test(
      '409 (ventana vencida / no editable) → MessagesConflictFailure',
      () async {
        stubPostThrow(postBad(409));
        await expectLater(
          ds.editMessage('b1', 'lid-1', messageId: 'm1', newText: 'x'),
          throwsA(isA<MessagesConflictFailure>()),
        );
      },
    );

    test('423 (bot pausado) → MessagesBotPausedFailure', () async {
      stubPostThrow(postBad(423));
      await expectLater(
        ds.editMessage('b1', 'lid-1', messageId: 'm1', newText: 'x'),
        throwsA(isA<MessagesBotPausedFailure>()),
      );
    });
  });

  group('DioMessagesDatasource.revokeMessage', () {
    test('200 → Message revocado; path + body', () async {
      stubPost(
        postResp(
          200,
          body: <String, dynamic>{
            ...msgJson(externalId: 'm1', direction: 'OUTBOUND', status: 'SENT'),
            'revokedAtMs': 1900,
          },
        ),
      );
      final m = await ds.revokeMessage('b1', 'lid-1', messageId: 'm1');
      final c = capturedPost();
      expect(c[0], '/sessions/b1/lid-1/messages/revoke');
      expect(c[1], <String, dynamic>{'messageId': 'm1'});
      expect(m.revokedAtMs, 1900);
    });

    test('404 → MessagesNotFoundFailure', () async {
      stubPostThrow(postBad(404));
      await expectLater(
        ds.revokeMessage('b1', 'lid-1', messageId: 'm1'),
        throwsA(isA<MessagesNotFoundFailure>()),
      );
    });

    test('503 (bot no corriendo) → MessagesNotConnectedFailure', () async {
      stubPostThrow(postBad(503));
      await expectLater(
        ds.revokeMessage('b1', 'lid-1', messageId: 'm1'),
        throwsA(isA<MessagesNotConnectedFailure>()),
      );
    });
  });
}
