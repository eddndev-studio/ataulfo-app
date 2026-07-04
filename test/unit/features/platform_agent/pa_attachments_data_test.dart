import 'package:ataulfo/features/platform_agent/data/datasources/platform_agent_datasource.dart';
import 'package:ataulfo/features/platform_agent/data/dto/pa_dtos.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _resp(String path, Map<String, dynamic> body) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
      data: body,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(FormData());
    registerFallbackValue(Options());
  });

  group('PaMessageDto.attachments', () {
    test('parsea los adjuntos del wire', () {
      final dto = PaMessageDto.fromJson(<String, dynamic>{
        'id': 'm1',
        'conversation_id': 'c1',
        'role': 'user',
        'content': 'mira',
        'created_at': '2026-06-12T10:00:00.000Z',
        'attachments': <dynamic>[
          <String, dynamic>{
            'ref': 'tenant/org/media/a1.png',
            'mime': 'image/png',
            'name': 'catalogo.png',
            'sizeBytes': 2048,
          },
        ],
      });
      final m = dto.toEntity();
      expect(m.attachments, hasLength(1));
      expect(m.attachments.single.name, 'catalogo.png');
      expect(m.attachments.single.mime, 'image/png');
    });

    test('sin attachments en el wire la lista queda vacía (wire viejo)', () {
      final dto = PaMessageDto.fromJson(<String, dynamic>{
        'id': 'm1',
        'conversation_id': 'c1',
        'role': 'user',
        'content': 'hola',
        'created_at': '2026-06-12T10:00:00.000Z',
      });
      expect(dto.toEntity().attachments, isEmpty);
    });

    test('un adjunto malformado se omite (tolerante)', () {
      final dto = PaMessageDto.fromJson(<String, dynamic>{
        'id': 'm1',
        'conversation_id': 'c1',
        'role': 'user',
        'content': 'mira',
        'created_at': '2026-06-12T10:00:00.000Z',
        'attachments': <dynamic>[
          <String, dynamic>{
            'ref': 'ok',
            'mime': 'application/pdf',
            'name': 'x.pdf',
            'sizeBytes': 4,
          },
          <String, dynamic>{'ref': 42}, // basura: se descarta sin caerse
        ],
      });
      expect(dto.toEntity().attachments, hasLength(1));
    });
  });

  group('PaModelsDto flags de modalidad', () {
    test('adopta imageInput/pdfInput cuando el wire los trae como bool', () {
      final dto = PaModelsDto.fromJson(<String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{
            'id': 'g',
            'label': 'Gemini',
            'imageInput': true,
            'pdfInput': false,
          },
        ],
        'default': 'g',
      });
      expect(dto.options.single.imageInput, isTrue);
      expect(dto.options.single.pdfInput, isFalse);
    });

    test('flags ausentes ⇒ null (wire viejo, sin aviso)', () {
      final dto = PaModelsDto.fromJson(<String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{'id': 'm3', 'label': 'MiniMax M3'},
        ],
        'default': '',
      });
      expect(dto.options.single.imageInput, isNull);
      expect(dto.options.single.pdfInput, isNull);
    });
  });

  group('DioPlatformAgentDatasource adjuntos', () {
    late _MockDio dio;
    late DioPlatformAgentDatasource ds;

    setUp(() {
      dio = _MockDio();
      ds = DioPlatformAgentDatasource(dio);
    });

    test('uploadAttachment POSTea multipart y parsea la respuesta', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/platform-agent/attachments',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _resp('/platform-agent/attachments', <String, dynamic>{
          'ref': 'tenant/org/media/a1.png',
          'mime': 'image/png',
          'name': 'catalogo.png',
          'sizeBytes': 4,
        }),
      );

      final att = await ds.uploadAttachment(
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        filename: 'catalogo.png',
      );

      expect(att.ref, 'tenant/org/media/a1.png');
      expect(att.name, 'catalogo.png');
      expect(att.sizeBytes, 4);
      final captured =
          verify(
                () => dio.post<Map<String, dynamic>>(
                  '/platform-agent/attachments',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as FormData;
      expect(captured.files.single.key, 'file');
    });

    test('sendMessage incluye las refs cuando hay adjuntos', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/platform-agent/conversations/c1/messages',
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => _resp(
          '/platform-agent/conversations/c1/messages',
          <String, dynamic>{
            'id': 'm9',
            'conversation_id': 'c1',
            'role': 'assistant',
            'content': 'la veo',
            'created_at': '2026-06-12T10:00:00.000Z',
          },
        ),
      );

      await ds.sendMessage(
        conversationId: 'c1',
        content: 'mira',
        attachments: const <String>['tenant/org/media/a1.png'],
      );

      final captured =
          verify(
                () => dio.post<Map<String, dynamic>>(
                  '/platform-agent/conversations/c1/messages',
                  data: captureAny(named: 'data'),
                  options: any(named: 'options'),
                  cancelToken: any(named: 'cancelToken'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured['attachments'], <String>['tenant/org/media/a1.png']);
    });

    test('sendMessage sin adjuntos NO manda la clave attachments', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/platform-agent/conversations/c1/messages',
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => _resp(
          '/platform-agent/conversations/c1/messages',
          <String, dynamic>{
            'id': 'm9',
            'conversation_id': 'c1',
            'role': 'assistant',
            'content': 'ok',
            'created_at': '2026-06-12T10:00:00.000Z',
          },
        ),
      );

      await ds.sendMessage(conversationId: 'c1', content: 'hola');

      final captured =
          verify(
                () => dio.post<Map<String, dynamic>>(
                  '/platform-agent/conversations/c1/messages',
                  data: captureAny(named: 'data'),
                  options: any(named: 'options'),
                  cancelToken: any(named: 'cancelToken'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured.containsKey('attachments'), isFalse);
    });
  });
}
