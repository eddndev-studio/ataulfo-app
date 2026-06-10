import 'package:ataulfo/features/trainer/data/datasources/preview_datasource.dart';
import 'package:ataulfo/features/trainer/data/dto/preview_dtos.dart';
import 'package:ataulfo/features/trainer/domain/failures/trainer_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> itemJson({
  String kind = 'bot',
  String text = '¡Hola!',
  String tool = '',
  String summary = '',
}) => <String, dynamic>{
  'kind': kind,
  if (text.isNotEmpty) 'text': text,
  if (tool.isNotEmpty) 'tool': tool,
  if (summary.isNotEmpty) 'summary': summary,
  'at': '2026-06-10T12:00:00.000Z',
};

void main() {
  late _MockDio dio;
  late DioPreviewDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioPreviewDatasource(dio);
  });

  test('PreviewItemDto discrimina user/bot/action', () {
    final bot = PreviewItemDto.fromJson(itemJson());
    expect(bot.kind, 'bot');
    expect(bot.text, '¡Hola!');

    final action = PreviewItemDto.fromJson(
      itemJson(kind: 'action', text: '', tool: 'apply_label', summary: 'Etiquetaría: VIP'),
    );
    expect(action.tool, 'apply_label');
    expect(action.summary, 'Etiquetaría: VIP');
    expect(action.text, '');
  });

  test('POST corre el turno y devuelve items+iterations', () async {
    when(
      () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 201,
        data: <String, dynamic>{
          'items': <dynamic>[
            itemJson(kind: 'user', text: 'hola'),
            itemJson(),
          ],
          'iterations': 2,
        },
      ),
    );
    final turn = await ds.sendMessage(templateId: 't1', content: 'hola');
    expect(turn.items, hasLength(2));
    expect(turn.iterations, 2);
    verify(
      () => dio.post<Map<String, dynamic>>(
        '/templates/t1/preview/messages',
        data: <String, dynamic>{'content': 'hola'},
      ),
    ).called(1);
  });

  test('GET rehidrata el transcript', () async {
    when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/x'),
        data: <String, dynamic>{
          'items': <dynamic>[itemJson()],
        },
      ),
    );
    final items = await ds.transcript(templateId: 't1');
    expect(items, hasLength(1));
  });

  test('DELETE resetea la sesión', () async {
    when(() => dio.delete<void>(any())).thenAnswer(
      (_) async => Response(requestOptions: RequestOptions(path: '/x')),
    );
    await ds.reset(templateId: 't1');
    verify(() => dio.delete<void>('/templates/t1/preview')).called(1);
  });

  test('503 sin sandbox ⇒ TrainerUnavailableFailure', () async {
    when(
      () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 503,
        ),
        type: DioExceptionType.badResponse,
      ),
    );
    await expectLater(
      () => ds.sendMessage(templateId: 't1', content: 'x'),
      throwsA(isA<TrainerUnavailableFailure>()),
    );
  });
}
