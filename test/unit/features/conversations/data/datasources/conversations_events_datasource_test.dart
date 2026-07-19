import 'dart:convert';
import 'dart:typed_data';

import 'package:ataulfo/features/conversations/data/datasources/conversations_events_datasource.dart';
import 'package:ataulfo/features/conversations/domain/entities/inbox_live_event.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioConversationsEventsDatasource datasource;

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
  });

  setUp(() {
    dio = _MockDio();
    datasource = DioConversationsEventsDatasource(dio);
  });

  Response<ResponseBody> sse(String frames) => Response<ResponseBody>(
    requestOptions: RequestOptions(path: '/inbox/events'),
    statusCode: 200,
    data: ResponseBody(
      Stream<Uint8List>.fromIterable(<Uint8List>[
        Uint8List.fromList(utf8.encode(frames)),
      ]),
      200,
    ),
  );

  String frame(String topic, Map<String, dynamic> data) =>
      'event: $topic\ndata: ${jsonEncode(data)}\n\n';

  void stub(String frames) {
    when(
      () => dio.get<ResponseBody>(
        '/inbox/events',
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => sse(frames));
  }

  test('proyecta invalidación operativa por identidad compuesta', () async {
    stub(
      frame('agent.alert', <String, dynamic>{
        'botId': 'bot-1',
        'chatLid': 'lid-1',
        'needsAttention': true,
        // El cliente ignora cualquier campo futuro y nunca lo lleva al estado.
        'detail': 'dato que no pertenece al contrato de bandeja',
      }),
    );

    final events = await datasource.connectOnce().toList();

    expect(events, const <InboxLiveEvent>[
      InboxInvalidated(
        topic: 'agent.alert',
        botId: 'bot-1',
        chatLid: 'lid-1',
        needsAttention: true,
      ),
    ]);
  });

  test(
    'label.assigned ignora IDs de catálogo y sólo invalida el chat',
    () async {
      stub(
        frame('label.assigned', <String, dynamic>{
          'botId': 'bot-1',
          'chatLid': 'lid-1',
          'labelId': 'vip',
        }),
      );

      final event = (await datasource.connectOnce().toList()).single;

      expect(
        event,
        const InboxInvalidated(
          topic: 'label.assigned',
          botId: 'bot-1',
          chatLid: 'lid-1',
        ),
      );
    },
  );

  test('topic ajeno y frame malformado se omiten', () async {
    stub(
      '${frame('label.wa.chat', <String, dynamic>{'botId': 'bot-1', 'chatLid': 'lid-1'})}event: message.inbound\ndata: {roto\n\n',
    );

    expect(await datasource.connectOnce().toList(), isEmpty);
  });

  test('liveEvents emite reconexión para reconciliar por REST', () async {
    var calls = 0;
    when(
      () => dio.get<ResponseBody>(
        '/inbox/events',
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async {
      calls++;
      return sse(
        frame('message.inbound', <String, dynamic>{
          'botId': 'bot-1',
          'chatLid': 'lid-$calls',
        }),
      );
    });

    final events = await datasource.liveEvents().take(3).toList();

    expect(events[0], isA<InboxInvalidated>());
    expect(events[1], const InboxReconnected());
    expect(events[2], isA<InboxInvalidated>());
  });
}
