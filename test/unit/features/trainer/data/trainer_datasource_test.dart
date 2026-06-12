import 'package:ataulfo/features/trainer/data/datasources/trainer_datasource.dart';
import 'package:ataulfo/features/trainer/data/dto/trainer_dtos.dart';
import 'package:ataulfo/features/trainer/domain/failures/trainer_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> convJson({String id = 'c1'}) => <String, dynamic>{
  'id': id,
  'org_id': 'org1',
  'template_id': 't1',
  'operator_id': 'u1',
  'title': 'Entrenamiento',
  'created_at': '2026-06-10T10:00:00.000Z',
  'updated_at': '2026-06-10T11:00:00.000Z',
};

Map<String, dynamic> msgJson({
  String role = 'assistant',
  String content = 'te ayudo',
  Object? toolResults,
}) => <String, dynamic>{
  'id': 'm1',
  'conversation_id': 'c1',
  'role': role,
  'content': content,
  'tool_results': ?toolResults,
  'created_at': '2026-06-10T10:00:01.000Z',
};

void main() {
  late _MockDio dio;
  late DioTrainerDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioTrainerDatasource(dio);
  });

  group('DTOs', () {
    test('conversación parsea snake_case', () {
      final c = TrainerConversationDto.fromJson(convJson());
      expect(c.id, 'c1');
      expect(c.templateId, 't1');
      expect(c.title, 'Entrenamiento');
    });

    test('mensaje conserva tool_results CRUDO para las tarjetas de cambio', () {
      final m = TrainerMessageDto.fromJson(
        msgJson(
          role: 'tool',
          content: '',
          toolResults: <String, dynamic>{
            'toolName': 'edit_prompt',
            'content': '{"status":"updated"}',
          },
        ),
      );
      expect(m.role, 'tool');
      expect(m.toolResultsRaw, isNotNull);
      expect(m.toolResultsRaw, contains('edit_prompt'));
    });

    test('content ausente en assistant ⇒ cadena vacía (tolerante)', () {
      final json = msgJson()..remove('content');
      expect(TrainerMessageDto.fromJson(json).content, '');
    });
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
      final c = await ds.createConversation(templateId: 't1', title: 'Hilo');
      expect(c.id, 'c1');
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/templates/t1/trainer/conversations',
          data: <String, dynamic>{'title': 'Hilo'},
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
      final list = await ds.listConversations(templateId: 't1');
      expect(list, hasLength(2));
    });
  });

  group('mensajes', () {
    test('GET con cursor+limit y desempaca {messages, next_cursor}', () async {
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
        templateId: 't1',
        conversationId: 'c1',
        cursor: 'abc',
        limit: 30,
      );
      expect(page.messages, hasLength(1));
      expect(page.nextCursor, 'tok');
      verify(
        () => dio.get<Map<String, dynamic>>(
          '/templates/t1/trainer/conversations/c1/messages',
          queryParameters: <String, dynamic>{'cursor': 'abc', 'limit': '30'},
        ),
      ).called(1);
    });

    test('POST devuelve el turno final del asistente', () async {
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
        templateId: 't1',
        conversationId: 'c1',
        content: 'entrena mi bot',
      );
      expect(m.role, 'assistant');
      expect(m.content, 'te ayudo');
    });

    test(
      'POST del turno sobreescribe receiveTimeout (turno > global)',
      () async {
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
          templateId: 't1',
          conversationId: 'c1',
          content: 'x',
        );
        final captured = verify(
          () => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: captureAny(named: 'options'),
          ),
        ).captured;
        final opts = captured.single as Options?;
        expect(
          opts?.receiveTimeout,
          const Duration(seconds: 180),
          reason:
              'el turno síncrono debe esperar más que el presupuesto '
              'del motor en el server; el global de Dio (30s) lo cortaría antes',
        );
      },
    );

    test(
      'POST con modelo elegido manda `model`; sin elección lo omite',
      () async {
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
          templateId: 't1',
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

        await ds.sendMessage(
          templateId: 't1',
          conversationId: 'c1',
          content: 'x',
        );
        captured = verify(
          () => dio.post<Map<String, dynamic>>(
            any(),
            data: captureAny(named: 'data'),
            options: any(named: 'options'),
          ),
        ).captured;
        expect(captured.single, <String, dynamic>{'content': 'x'});
      },
    );

    test('502 del motor ⇒ TrainerEngineFailure', () async {
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
        () => ds.sendMessage(
          templateId: 't1',
          conversationId: 'c1',
          content: 'x',
        ),
        throwsA(isA<TrainerEngineFailure>()),
      );
    });
  });

  group('modelos del entrenador', () {
    test('GET models desempaca {items, default}', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          data: <String, dynamic>{
            'items': <dynamic>[
              <String, dynamic>{
                'id': 'gemini-3.1-pro-preview',
                'label': 'Gemini 3.1 Pro',
              },
              <String, dynamic>{'id': 'gpt-5.5', 'label': 'ChatGPT 5.5'},
              <String, dynamic>{'id': 'MiniMax-M3', 'label': 'MiniMax M3'},
            ],
            'default': 'gpt-5.5',
          },
        ),
      );
      final models = await ds.listModels(templateId: 't1');
      expect(models.options, hasLength(3));
      expect(models.options[1].id, 'gpt-5.5');
      expect(models.options[1].label, 'ChatGPT 5.5');
      expect(models.defaultId, 'gpt-5.5');
      verify(
        () => dio.get<Map<String, dynamic>>('/templates/t1/trainer/models'),
      ).called(1);
    });

    test('default ausente (backend sin config) degrada a vacío', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          data: <String, dynamic>{'items': <dynamic>[]},
        ),
      );
      final models = await ds.listModels(templateId: 't1');
      expect(models.options, isEmpty);
      expect(models.defaultId, '');
    });
  });
}
