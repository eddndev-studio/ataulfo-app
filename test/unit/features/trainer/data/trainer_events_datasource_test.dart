import 'dart:convert';
import 'dart:typed_data';

import 'package:ataulfo/features/trainer/data/datasources/trainer_events_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioTrainerEventsDatasource ds;

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
  });

  setUp(() {
    dio = _MockDio();
    ds = DioTrainerEventsDatasource(dio);
  });

  /// Respuesta SSE: el `data` de Dio es un ResponseBody que envuelve el stream
  /// de bytes de los frames concatenados.
  Response<ResponseBody> sse(String frames) => Response<ResponseBody>(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: 200,
    data: ResponseBody(
      Stream<Uint8List>.fromIterable(<Uint8List>[
        Uint8List.fromList(utf8.encode(frames)),
      ]),
      200,
    ),
  );

  String frame(String event, String data) => 'event: $event\ndata: $data\n\n';

  void stub(Response<ResponseBody> r) {
    when(
      () => dio.get<ResponseBody>(
        any(),
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => r);
  }

  test('abre el stream SSE en la ruta canónica del entrenador', () async {
    stub(sse(''));

    await ds.connectOnce('t1', 'c1').toList();

    final captured = verify(
      () => dio.get<ResponseBody>(
        captureAny(),
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      ),
    ).captured;
    expect(
      captured.single,
      '/templates/t1/trainer/conversations/c1/stream',
      reason:
          'el server registra /templates/{id}/trainer/conversations/{id}/stream; '
          'la ruta invertida /trainer/templates/... da 404 y mata el indicador '
          'en vivo en silencio',
    );
  });

  test('filtra por topic del bus y mapea a TrainerProgressEvent', () async {
    stub(
      sse(
        frame(
              'trainer_agent.thinking',
              jsonEncode(<String, dynamic>{
                'kind': 'thinking',
                'conversationId': 'c1',
              }),
            ) +
            frame(
              'unrelated.topic',
              jsonEncode(<String, dynamic>{
                'kind': 'noise',
                'conversationId': 'c1',
              }),
            ),
      ),
    );

    final got = await ds.connectOnce('t1', 'c1').toList();

    expect(got, hasLength(1));
    expect(got.single.kind, 'thinking');
    expect(got.single.conversationId, 'c1');
  });
}
