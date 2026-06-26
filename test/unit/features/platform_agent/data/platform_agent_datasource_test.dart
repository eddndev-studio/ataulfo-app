import 'package:ataulfo/features/platform_agent/data/datasources/platform_agent_datasource.dart';
import 'package:ataulfo/features/platform_agent/data/repositories/platform_agent_repositories_impl.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_conversation.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_message.dart';
import 'package:ataulfo/features/platform_agent/domain/failures/pa_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _MockDs extends Mock implements PlatformAgentDatasource {}

Map<String, dynamic> convJson({String id = 'c1'}) => <String, dynamic>{
  'id': id,
  'org_id': 'org1',
  'operator_id': 'u1',
  'title': 'Operación',
  'created_at': '2026-06-10T10:00:00.000Z',
  'updated_at': '2026-06-10T11:00:00.000Z',
};

Map<String, dynamic> msgJson() => <String, dynamic>{
  'id': 'm1',
  'conversation_id': 'c1',
  'role': 'assistant',
  'content': 'tienes 3 bots',
  'created_at': '2026-06-10T10:00:01.000Z',
};

void main() {
  late _MockDio dio;
  late DioPlatformAgentDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioPlatformAgentDatasource(dio);
  });

  group('conversaciones', () {
    test('POST crea hilo con title opcional', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 201,
          data: convJson(),
        ),
      );
      final c = await ds.createConversation(title: 'Hilo');
      expect(c.id, 'c1');
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/platform-agent/conversations',
          data: <String, dynamic>{'title': 'Hilo'},
        ),
      ).called(1);
    });

    test('POST sin title manda body vacío', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 201,
          data: convJson(),
        ),
      );
      await ds.createConversation();
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/platform-agent/conversations',
          data: <String, dynamic>{},
        ),
      ).called(1);
    });

    test('GET lista array top-level', () async {
      when(() => dio.get<List<dynamic>>(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          data: <dynamic>[
            convJson(),
            convJson(id: 'c2'),
          ],
        ),
      );
      final list = await ds.listConversations();
      expect(list, hasLength(2));
      verify(
        () => dio.get<List<dynamic>>('/platform-agent/conversations'),
      ).called(1);
    });

    test('PATCH renombra el hilo (id en el path, title en el body)', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 200,
          data: convJson(),
        ),
      );
      final c = await ds.renameConversation('c1', 'Soporte VIP');
      expect(c.id, 'c1');
      verify(
        () => dio.patch<Map<String, dynamic>>(
          '/platform-agent/conversations/c1',
          data: <String, dynamic>{'title': 'Soporte VIP'},
        ),
      ).called(1);
    });

    test('DELETE borra el hilo (id en el path)', () async {
      when(() => dio.delete<void>(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 204,
        ),
      );
      await ds.deleteConversation('c1');
      verify(
        () => dio.delete<void>('/platform-agent/conversations/c1'),
      ).called(1);
    });
  });

  group('mensajes', () {
    test('GET con cursor+limit desempaca {messages, next_cursor}', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          data: <String, dynamic>{
            'messages': <dynamic>[msgJson()],
            'next_cursor': 'tok',
          },
        ),
      );
      final page = await ds.listMessages(
        conversationId: 'c1',
        cursor: 'abc',
        limit: 30,
      );
      expect(page.messages, hasLength(1));
      expect(page.nextCursor, 'tok');
      verify(
        () => dio.get<Map<String, dynamic>>(
          '/platform-agent/conversations/c1/messages',
          queryParameters: <String, dynamic>{'cursor': 'abc', 'limit': '30'},
        ),
      ).called(1);
    });

    test('POST del turno devuelve el assistant final', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 201,
          data: msgJson(),
        ),
      );
      final m = await ds.sendMessage(
        conversationId: 'c1',
        content: '¿cuántos bots tengo?',
      );
      expect(m.role, 'assistant');
      expect(m.content, 'tienes 3 bots');
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/platform-agent/conversations/c1/messages',
          data: <String, dynamic>{'content': '¿cuántos bots tengo?'},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('POST del turno sobreescribe receiveTimeout a 180s', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 201,
          data: msgJson(),
        ),
      );
      await ds.sendMessage(conversationId: 'c1', content: 'x');
      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: captureAny(named: 'options'),
        ),
      ).captured;
      final opts = captured.single as Options?;
      expect(opts?.receiveTimeout, const Duration(seconds: 180));
    });

    test('502 del motor ⇒ PaEngineFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 502,
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      await expectLater(
        () => ds.sendMessage(conversationId: 'c1', content: 'x'),
        throwsA(isA<PaEngineFailure>()),
      );
    });

    test('404 ⇒ PaNotFoundFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 404,
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      await expectLater(
        () => ds.listMessages(conversationId: 'nope'),
        throwsA(isA<PaNotFoundFailure>()),
      );
    });
  });

  group('repo impl delega al datasource', () {
    late _MockDs mock;
    late PlatformAgentRepositoryImpl repo;

    setUp(() {
      mock = _MockDs();
      repo = PlatformAgentRepositoryImpl(datasource: mock);
    });

    test('sendMessage delega', () async {
      final msg = PaMessage(
        id: 'm1',
        conversationId: 'c1',
        role: 'assistant',
        content: 'ok',
        createdAt: DateTime.utc(2026),
      );
      when(
        () => mock.sendMessage(
          conversationId: any(named: 'conversationId'),
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async => msg);
      final out = await repo.sendMessage(conversationId: 'c1', content: 'hola');
      expect(out, msg);
      verify(
        () => mock.sendMessage(conversationId: 'c1', content: 'hola'),
      ).called(1);
    });

    test('createConversation delega', () async {
      final conv = PaConversation(
        id: 'c1',
        title: '',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      when(
        () => mock.createConversation(title: any(named: 'title')),
      ).thenAnswer((_) async => conv);
      final out = await repo.createConversation();
      expect(out, conv);
    });
  });

  group('modelos', () {
    test('GET /platform-agent/models desempaca {items, default}', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          data: <String, dynamic>{
            'items': <dynamic>[
              <String, dynamic>{'id': 'gpt-5.5', 'label': 'ChatGPT 5.5'},
              <String, dynamic>{'id': 'MiniMax-M3', 'label': 'MiniMax M3'},
            ],
            'default': 'gemini-3.1-pro-preview',
          },
        ),
      );
      final models = await ds.listModels();
      expect(models.options, hasLength(2));
      expect(models.options[0].id, 'gpt-5.5');
      expect(models.defaultId, 'gemini-3.1-pro-preview');
      verify(
        () => dio.get<Map<String, dynamic>>('/platform-agent/models'),
      ).called(1);
    });

    test('POST del turno manda `model`; sin elección lo omite', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 201,
          data: msgJson(),
        ),
      );

      await ds.sendMessage(
        conversationId: 'c1',
        content: 'hola',
        model: 'gpt-5.5',
      );
      var captured = verify(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured.single, <String, dynamic>{
        'content': 'hola',
        'model': 'gpt-5.5',
      });

      await ds.sendMessage(conversationId: 'c1', content: 'x');
      captured = verify(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured.single, <String, dynamic>{'content': 'x'});
    });
  });
}
