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
  if (toolResults != null) 'tool_results': toolResults,
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
          data: <dynamic>[convJson(), convJson(id: 'c2')],
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
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
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

    test('502 del motor ⇒ TrainerEngineFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
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
        () => ds.sendMessage(templateId: 't1', conversationId: 'c1', content: 'x'),
        throwsA(isA<TrainerEngineFailure>()),
      );
    });
  });
}
