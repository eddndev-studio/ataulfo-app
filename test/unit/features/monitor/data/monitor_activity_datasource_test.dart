import 'dart:convert';
import 'dart:typed_data';

import 'package:ataulfo/features/monitor/data/datasources/monitor_activity_datasource.dart';
import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioMonitorActivityDatasource ds;

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
  });

  setUp(() {
    dio = _MockDio();
    ds = DioMonitorActivityDatasource(dio);
  });

  /// Respuesta SSE: el `data` de Dio es un ResponseBody que envuelve el stream
  /// de bytes de los frames concatenados.
  Response<ResponseBody> sse(String frames) => Response<ResponseBody>(
    requestOptions: RequestOptions(path: '/ai-activity'),
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

  final turnFrame = frame(
    'ai.turn',
    jsonEncode(<String, dynamic>{'runId': 'R1'}),
  );

  test(
    'activity emite un sentinel connected al establecer la conexión, antes de los frames',
    () async {
      stub(sse(turnFrame));
      final got = await ds.activity('b1', 'c1').take(2).toList();
      expect(got.first.kind, MonitorEventKind.connected);
      expect(got[1].kind, MonitorEventKind.aiTurn);
    },
  );

  test(
    'botActivity NO emite connected (la bandeja no pinta salud del SSE)',
    () async {
      stub(sse(turnFrame));
      final got = await ds.botActivity('b1').take(1).toList();
      expect(got.single.kind, MonitorEventKind.aiTurn);
    },
  );
}
