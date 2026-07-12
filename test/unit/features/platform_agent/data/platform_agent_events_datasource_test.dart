import 'dart:convert';
import 'dart:typed_data';

import 'package:ataulfo/features/platform_agent/data/datasources/platform_agent_events_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioPlatformAgentEventsDatasource ds;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
  });

  setUp(() {
    dio = _MockDio();
    ds = DioPlatformAgentEventsDatasource(dio);
  });

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

  // Wire-fiel: el `data.kind` del paWire va en MAYÚSCULAS ("THINKING"/"TOOL"/
  // "COMPLETED"/"FAILED", aseverado por el stream_test.go del backend). El
  // cliente NO debe depender de su case: el kind canónico sale del topic.
  String progJson({
    required String kind,
    String conversationId = 'c1',
    String toolName = '',
  }) => jsonEncode(<String, dynamic>{
    'runId': 'r1',
    'conversationId': conversationId,
    'iteration': 1,
    'kind': kind,
    if (toolName.isNotEmpty) 'toolName': toolName,
    'at': '2026-06-10T10:00:00.000Z',
  });

  void stub(Response<ResponseBody> r) {
    when(
      () => dio.get<ResponseBody>(
        any(),
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => r);
  }

  test('emite PaProgressEvent para thinking y tool', () async {
    stub(
      sse(
        frame('platform_agent.thinking', progJson(kind: 'THINKING')) +
            frame(
              'platform_agent.tool',
              progJson(kind: 'TOOL', toolName: 'list_bots'),
            ),
      ),
    );

    final got = await ds.connectOnce('c1').toList();

    expect(got, hasLength(2));
    expect(got[0].isThinking, isTrue);
    expect(got[1].isTool, isTrue);
    expect(got[1].toolName, 'list_bots');
  });

  test('emite completed y failed (terminales)', () async {
    stub(
      sse(
        frame('platform_agent.completed', progJson(kind: 'COMPLETED')) +
            frame('platform_agent.failed', progJson(kind: 'FAILED')),
      ),
    );

    final got = await ds.connectOnce('c1').toList();

    expect(got, hasLength(2));
    expect(got[0].isCompleted, isTrue);
    expect(got[0].isTerminal, isTrue);
    expect(got[1].isFailed, isTrue);
  });

  test('el kind sale del TOPIC: gana sobre un data.kind discrepante', () async {
    stub(
      sse(
        frame(
          'platform_agent.tool',
          progJson(kind: 'THINKING', toolName: 'list_bots'),
        ),
      ),
    );

    final got = await ds.connectOnce('c1').toList();

    expect(got.single.isTool, isTrue);
    expect(got.single.isThinking, isFalse);
    expect(got.single.toolName, 'list_bots');
  });

  test('data sin kind se parsea igual (el kind sale del topic)', () async {
    stub(
      sse(
        frame(
          'platform_agent.completed',
          jsonEncode(<String, dynamic>{
            'runId': 'r1',
            'conversationId': 'c1',
            'iteration': 1,
            'at': '2026-06-10T10:00:00.000Z',
          }),
        ),
      ),
    );

    final got = await ds.connectOnce('c1').toList();

    expect(got.single.isCompleted, isTrue);
    expect(got.single.isTerminal, isTrue);
  });

  test('filtra topics ajenos (message.inbound, bot.session)', () async {
    stub(
      sse(
        frame('message.inbound', '{"x":1}') +
            frame('bot.session', '{"state":"CONNECTED"}') +
            frame('platform_agent.tool', progJson(kind: 'TOOL')),
      ),
    );

    final got = await ds.connectOnce('c1').toList();

    expect(got, hasLength(1));
    expect(got.single.isTool, isTrue);
  });

  test('un frame malformado se omite sin derribar el stream', () async {
    stub(
      sse(
        frame('platform_agent.tool', '{no es json}') +
            frame('platform_agent.completed', progJson(kind: 'COMPLETED')),
      ),
    );

    final got = await ds.connectOnce('c1').toList();

    expect(got, hasLength(1));
    expect(got.single.isCompleted, isTrue);
  });

  test('pide /platform-agent/conversations/{id}/stream', () async {
    stub(sse(''));
    await ds.connectOnce('c9').toList();

    final captured = verify(
      () => dio.get<ResponseBody>(
        captureAny(),
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      ),
    ).captured;
    expect(captured.single, '/platform-agent/conversations/c9/stream');
  });

  test('progress() envuelve la conexión (emite el primer evento)', () async {
    stub(sse(frame('platform_agent.thinking', progJson(kind: 'THINKING'))));

    final first = await ds.progress('c1').first;

    expect(first.isThinking, isTrue);
  });
}
