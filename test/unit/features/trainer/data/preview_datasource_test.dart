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
      itemJson(
        kind: 'action',
        text: '',
        tool: 'apply_label',
        summary: 'Etiquetaría: VIP',
      ),
    );
    expect(action.tool, 'apply_label');
    expect(action.summary, 'Etiquetaría: VIP');
    expect(action.text, '');
  });

  test('PreviewItemDto parsea media (ref + tipo de paso + caption)', () {
    final media = PreviewItemDto.fromJson(
      itemJson(kind: 'media', text: 'Catálogo 2026')
        ..['mediaRef'] = 'ref-7'
        ..['stepType'] = 'IMAGE',
    );
    expect(media.kind, 'media');
    final entity = media.toEntity();
    expect(entity.isMedia, isTrue);
    expect(entity.mediaRef, 'ref-7');
    expect(entity.stepType, 'IMAGE');
    expect(entity.text, 'Catálogo 2026');
  });

  test('PreviewItemDto parsea delayMs (cadencia del paso simulado)', () {
    final paced = PreviewItemDto.fromJson(
      itemJson(kind: 'bot', text: 'uno')..['delayMs'] = 1500,
    );
    expect(paced.toEntity().delayMs, 1500);
    // Ausente (turnos sin flujo / server viejo) ⇒ 0, sin romper.
    final plain = PreviewItemDto.fromJson(itemJson(kind: 'bot', text: 'ya'));
    expect(plain.toEntity().delayMs, 0);
  });

  test('POST corre el turno y devuelve items+iterations', () async {
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
        data: <String, dynamic>{
          'items': <dynamic>[itemJson(kind: 'user', text: 'hola'), itemJson()],
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
        options: any(named: 'options'),
      ),
    ).called(1);
  });

  test('POST del turno sobreescribe receiveTimeout (turno > global)', () async {
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
        data: <String, dynamic>{'items': <dynamic>[], 'iterations': 1},
      ),
    );
    await ds.sendMessage(templateId: 't1', content: 'hola');
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
  });

  test('GET rehidrata el transcript (sin ventana ⇒ no pending)', () async {
    when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/x'),
        data: <String, dynamic>{
          'items': <dynamic>[itemJson()],
        },
      ),
    );
    final t = await ds.transcript(templateId: 't1');
    expect(t.items, hasLength(1));
    expect(t.pending, isFalse);
    expect(t.windowEndsAt, isNull);
  });

  test('POST con ventana abierta parsea pending + windowEndsAt', () async {
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
        data: <String, dynamic>{
          'items': <dynamic>[itemJson(kind: 'user', text: 'hola')],
          'iterations': 0,
          'pending': true,
          'windowEndsAt': '2026-06-12T12:00:30.000Z',
        },
      ),
    );
    final turn = await ds.sendMessage(templateId: 't1', content: 'hola');
    expect(turn.pending, isTrue);
    expect(turn.windowEndsAt, DateTime.utc(2026, 6, 12, 12, 0, 30));
    expect(turn.items, hasLength(1));
  });

  test('GET con ventana viva parsea pending + windowEndsAt', () async {
    when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/x'),
        data: <String, dynamic>{
          'items': <dynamic>[itemJson(kind: 'user', text: 'hola')],
          'pending': true,
          'windowEndsAt': '2026-06-12T12:00:30.000Z',
        },
      ),
    );
    final t = await ds.transcript(templateId: 't1');
    expect(t.pending, isTrue);
    expect(t.windowEndsAt, DateTime.utc(2026, 6, 12, 12, 0, 30));
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
