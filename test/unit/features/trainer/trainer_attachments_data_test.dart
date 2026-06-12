import 'package:ataulfo/features/trainer/data/datasources/trainer_datasource.dart';
import 'package:ataulfo/features/trainer/data/dto/trainer_dtos.dart';
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

  group('TrainerMessageDto.attachments', () {
    test('parsea los adjuntos del wire', () {
      final dto = TrainerMessageDto.fromJson(<String, dynamic>{
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
      final dto = TrainerMessageDto.fromJson(<String, dynamic>{
        'id': 'm1',
        'conversation_id': 'c1',
        'role': 'user',
        'content': 'hola',
        'created_at': '2026-06-12T10:00:00.000Z',
      });
      expect(dto.toEntity().attachments, isEmpty);
    });
  });

  group('DioTrainerDatasource adjuntos', () {
    late _MockDio dio;
    late DioTrainerDatasource ds;

    setUp(() {
      dio = _MockDio();
      ds = DioTrainerDatasource(dio);
    });

    test('uploadAttachment POSTea multipart y parsea la respuesta', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/templates/t1/trainer/attachments',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async =>
            _resp('/templates/t1/trainer/attachments', <String, dynamic>{
              'ref': 'tenant/org/media/a1.png',
              'mime': 'image/png',
              'name': 'catalogo.png',
              'sizeBytes': 4,
            }),
      );

      final att = await ds.uploadAttachment(
        templateId: 't1',
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        filename: 'catalogo.png',
      );

      expect(att.ref, 'tenant/org/media/a1.png');
      expect(att.name, 'catalogo.png');
      expect(att.sizeBytes, 4);
      final captured =
          verify(
                () => dio.post<Map<String, dynamic>>(
                  '/templates/t1/trainer/attachments',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as FormData;
      expect(captured.files.single.key, 'file');
    });

    test('sendMessage incluye las refs cuando hay adjuntos', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/templates/t1/trainer/conversations/c1/messages',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _resp(
          '/templates/t1/trainer/conversations/c1/messages',
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
        templateId: 't1',
        conversationId: 'c1',
        content: 'mira',
        attachments: const <String>['tenant/org/media/a1.png'],
      );

      final captured =
          verify(
                () => dio.post<Map<String, dynamic>>(
                  '/templates/t1/trainer/conversations/c1/messages',
                  data: captureAny(named: 'data'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured['attachments'], <String>['tenant/org/media/a1.png']);
    });
  });
}
