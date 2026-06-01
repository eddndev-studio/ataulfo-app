import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/wa_labels/data/datasources/wa_assoc_datasource.dart';
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
  late DioWaAssocDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioWaAssocDatasource(dio);
  });

  DioException bad(int status, {String path = '/x'}) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('listChatAssocs / listMsgAssocs', () {
    test('GET chats → List<WaChatAssoc>', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/bots/b1/wa-labels/chats'),
          statusCode: 200,
          data: <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'chatLid': 'c1',
                'waLabelId': '1000',
                'labeled': true,
              },
            ],
          },
        ),
      );
      final cs = await ds.listChatAssocs('b1');
      expect(cs.single.chatLid, 'c1');
      final captured = verify(
        () => dio.get<Map<String, dynamic>>(
          captureAny(),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured.single, '/bots/b1/wa-labels/chats');
    });

    test('GET messages → List<WaMsgAssoc>; 403→Forbidden', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/bots/b1/wa-labels/messages'),
          statusCode: 200,
          data: <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'chatLid': 'c1',
                'messageId': 'wamid.1',
                'waLabelId': '1000',
                'labeled': false,
              },
            ],
          },
        ),
      );
      expect((await ds.listMsgAssocs('b1')).single.messageId, 'wamid.1');

      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(403));
      await expectLater(
        () => ds.listMsgAssocs('b1'),
        throwsA(isA<WaLabelsForbiddenFailure>()),
      );
    });
  });

  group('labelChat', () {
    test('PUT con chatLid percent-encodeado + body {kind, labeled}', () async {
      when(
        () => dio.put<void>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 200,
        ),
      );

      await ds.labelChat(
        botId: 'b1',
        waLabelId: '1000',
        chatLid: '123@g.us',
        kind: ConversationKind.group,
        labeled: true,
      );

      final captured = verify(
        () => dio.put<void>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/bots/b1/wa-labels/1000/chats/123%40g.us');
      final body = captured[1] as Map<String, dynamic>;
      expect(body['kind'], 'GROUP');
      expect(body['labeled'], isTrue);
    });

    test('labeled:false desasocia; kind DM', () async {
      when(
        () => dio.put<void>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 200,
        ),
      );
      await ds.labelChat(
        botId: 'b1',
        waLabelId: '1000',
        chatLid: 'c1',
        kind: ConversationKind.dm,
        labeled: false,
      );
      final captured = verify(
        () => dio.put<void>(
          any(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      final body = captured.single as Map<String, dynamic>;
      expect(body['kind'], 'DM');
      expect(body['labeled'], isFalse);
    });

    test('409→NotConnected, 502→Upstream, 422→Invalid', () async {
      for (final pair in <List<Object>>[
        <Object>[409, WaLabelsNotConnectedFailure],
        <Object>[502, WaLabelsUpstreamFailure],
        <Object>[422, WaLabelsInvalidFailure],
      ]) {
        when(
          () => dio.put<void>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenThrow(bad(pair[0] as int));
        await expectLater(
          () => ds.labelChat(
            botId: 'b1',
            waLabelId: '1000',
            chatLid: 'c1',
            kind: ConversationKind.dm,
            labeled: true,
          ),
          throwsA(predicate((e) => e.runtimeType == pair[1])),
        );
      }
    });
  });

  group('labelMessage', () {
    test(
      'PUT .../messages con body {chatLid, kind, messageId, labeled}',
      () async {
        when(
          () => dio.put<void>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response<void>(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 200,
          ),
        );

        await ds.labelMessage(
          botId: 'b1',
          waLabelId: '1000',
          chatLid: 'c1',
          kind: ConversationKind.dm,
          messageId: 'wamid.1',
          labeled: true,
        );

        final captured = verify(
          () => dio.put<void>(
            captureAny(),
            data: captureAny(named: 'data'),
            options: any(named: 'options'),
          ),
        ).captured;
        expect(captured[0], '/bots/b1/wa-labels/1000/messages');
        final body = captured[1] as Map<String, dynamic>;
        expect(body['chatLid'], 'c1');
        expect(body['kind'], 'DM');
        expect(body['messageId'], 'wamid.1');
        expect(body['labeled'], isTrue);
      },
    );

    test('409→NotConnected, 502→Upstream, 422→Invalid', () async {
      // labelMessage tiene su propio catch push(e); este loop evita que un
      // slip a read(e) mis-mapee silenciosamente (409/502→Unknown/Server).
      for (final pair in <List<Object>>[
        <Object>[409, WaLabelsNotConnectedFailure],
        <Object>[502, WaLabelsUpstreamFailure],
        <Object>[422, WaLabelsInvalidFailure],
      ]) {
        when(
          () => dio.put<void>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenThrow(bad(pair[0] as int));
        await expectLater(
          () => ds.labelMessage(
            botId: 'b1',
            waLabelId: '1000',
            chatLid: 'c1',
            kind: ConversationKind.dm,
            messageId: 'wamid.1',
            labeled: true,
          ),
          throwsA(predicate((e) => e.runtimeType == pair[1])),
        );
      }
    });
  });
}
