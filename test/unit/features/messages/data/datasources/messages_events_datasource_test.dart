import 'dart:convert';
import 'dart:typed_data';

import 'package:ataulfo/features/messages/data/datasources/messages_events_datasource.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/domain/entities/thread_live_event.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioMessagesEventsDatasource ds;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
  });

  setUp(() {
    dio = _MockDio();
    ds = DioMessagesEventsDatasource(dio);
  });

  /// Construye una respuesta SSE: el `data` de Dio es un ResponseBody que
  /// envuelve el stream de bytes de los frames concatenados.
  Response<ResponseBody> sse(String frames) => Response<ResponseBody>(
    requestOptions: RequestOptions(path: '/events/stream'),
    statusCode: 200,
    data: ResponseBody(
      Stream<Uint8List>.fromIterable(<Uint8List>[
        Uint8List.fromList(utf8.encode(frames)),
      ]),
      200,
    ),
  );

  String frame(String event, String data) => 'event: $event\ndata: $data\n\n';

  String msgJson({
    required String externalId,
    required String direction,
    String chatLid = 'lid-1',
    String content = 'hola',
  }) => jsonEncode(<String, dynamic>{
    'botId': 'b1',
    'chatLid': chatLid,
    'senderLid': 'bot',
    'kind': 'DM',
    'type': 'text',
    'content': content,
    'direction': direction,
    'externalId': externalId,
    'timestampMs': 1700,
  });

  String statusJson({required String externalId, required String status}) =>
      jsonEncode(<String, dynamic>{
        'botId': 'b1',
        'externalId': externalId,
        'status': status,
        'at': '2026-01-01T00:00:00Z',
      });

  void stub(Response<ResponseBody> r) {
    when(
      () => dio.get<ResponseBody>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => r);
  }

  Message asMessage(ThreadLiveEvent e) => (e as LiveMessage).message;

  test('emite LiveMessage para message.inbound y message.outbound', () async {
    stub(
      sse(
        frame('message.inbound', msgJson(externalId: 'in1', direction: 'INBOUND')) +
            frame(
              'message.outbound',
              msgJson(externalId: 'out1', direction: 'OUTBOUND'),
            ),
      ),
    );

    final got = await ds.connectOnce('b1').toList();

    expect(got, hasLength(2));
    expect(asMessage(got[0]).externalId, 'in1');
    expect(asMessage(got[0]).direction, MessageDirection.inbound);
    expect(asMessage(got[1]).externalId, 'out1');
    expect(asMessage(got[1]).direction, MessageDirection.outbound);
  });

  test('message.status emite LiveStatus (externalId + status)', () async {
    stub(sse(frame('message.status', statusJson(externalId: 'o1', status: 'READ'))));

    final got = await ds.connectOnce('b1').toList();

    expect(got, hasLength(1));
    expect(got.single, isA<LiveStatus>());
    final st = got.single as LiveStatus;
    expect(st.externalId, 'o1');
    expect(st.status, MessageStatus.read);
  });

  test('filtra topics sin burbuja ni receipt (bot.session, flow.*)', () async {
    stub(
      sse(
        frame('bot.session', '{"botId":"b1","state":"CONNECTED"}') +
            frame('flow.step', '{"botId":"b1","kind":"STEP","stepIdx":0}') +
            frame('message.outbound', msgJson(externalId: 'out1', direction: 'OUTBOUND')),
      ),
    );

    final got = await ds.connectOnce('b1').toList();

    expect(got, hasLength(1));
    expect(asMessage(got.single).externalId, 'out1');
  });

  test('un frame de mensaje malformado NO derriba el stream: se omite', () async {
    stub(
      sse(
        frame('message.outbound', '{esto no es json}') +
            frame('message.outbound', msgJson(externalId: 'ok', direction: 'OUTBOUND')),
      ),
    );

    final got = await ds.connectOnce('b1').toList();

    expect(got, hasLength(1));
    expect(asMessage(got.single).externalId, 'ok');
  });

  test('un frame message.status inválido se omite (json roto o status desconocido)', () async {
    stub(
      sse(
        frame('message.status', '{roto}') +
            frame('message.status', statusJson(externalId: 'x', status: 'PENDING')) +
            frame('message.status', statusJson(externalId: 'o1', status: 'DELIVERED')),
      ),
    );

    final got = await ds.connectOnce('b1').toList();

    expect(got, hasLength(1));
    expect((got.single as LiveStatus).externalId, 'o1');
    expect((got.single as LiveStatus).status, MessageStatus.delivered);
  });

  test('pide /events/stream con botId en query', () async {
    stub(sse(''));
    await ds.connectOnce('b1').toList();

    final captured = verify(
      () => dio.get<ResponseBody>(
        captureAny(),
        queryParameters: captureAny(named: 'queryParameters'),
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      ),
    ).captured;
    expect(captured[0], '/events/stream');
    expect(captured[1], <String, dynamic>{'botId': 'b1'});
  });

  test('threadEvents envuelve la conexión (emite LiveMessage)', () async {
    stub(
      sse(frame('message.outbound', msgJson(externalId: 'o1', direction: 'OUTBOUND'))),
    );

    // .first cancela tras el primer evento (corta el loop de reconexión).
    final first = await ds.threadEvents('b1').first;

    expect(first, isA<LiveMessage>());
    expect((first as LiveMessage).message.externalId, 'o1');
  });
}
