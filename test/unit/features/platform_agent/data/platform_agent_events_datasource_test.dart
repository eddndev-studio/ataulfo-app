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
        frame('platform_agent.thinking', progJson(kind: 'thinking')) +
            frame(
              'platform_agent.tool',
              progJson(kind: 'tool', toolName: 'list_bots'),
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
        frame('platform_agent.completed', progJson(kind: 'completed')) +
            frame('platform_agent.failed', progJson(kind: 'failed')),
      ),
    );

    final got = await ds.connectOnce('c1').toList();

    expect(got, hasLength(2));
    expect(got[0].isCompleted, isTrue);
    expect(got[0].isTerminal, isTrue);
    expect(got[1].isFailed, isTrue);
  });

  test('filtra topics ajenos (message.inbound, bot.session)', () async {
    stub(
      sse(
        frame('message.inbound', '{"x":1}') +
            frame('bot.session', '{"state":"CONNECTED"}') +
            frame('platform_agent.tool', progJson(kind: 'tool')),
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
            frame('platform_agent.completed', progJson(kind: 'completed')),
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
    stub(sse(frame('platform_agent.thinking', progJson(kind: 'thinking'))));

    final first = await ds.progress('c1').first;

    expect(first.isThinking, isTrue);
  });
}
