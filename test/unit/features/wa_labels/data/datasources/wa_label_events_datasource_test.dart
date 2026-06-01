import 'dart:convert';
import 'dart:typed_data';

import 'package:ataulfo/features/wa_labels/data/datasources/wa_label_events_datasource.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_live_event.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioWaLabelEventsDatasource ds;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
  });

  setUp(() {
    dio = _MockDio();
    ds = DioWaLabelEventsDatasource(dio);
  });

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

  /// Frame `label.wa.*` con el `kind` del data fundido. El topic (`event:`) y el
  /// `kind` del payload van 1:1 en el contrato (httpevents); ambos viajan.
  String waFrame(
    String topic,
    String kind, [
    Map<String, dynamic> over = const <String, dynamic>{},
  ]) => frame(
    topic,
    jsonEncode(<String, dynamic>{
      'botId': 'b1',
      'kind': kind,
      'waLabelId': '1000',
      'color': 3,
      'labeled': false,
      'at': '2026-05-31T12:00:00Z',
      ...over,
    }),
  );

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

  test('label.wa.edited → WaLabelCatalogChanged(removed:false)', () async {
    stub(
      sse(
        waFrame('label.wa.edited', 'EDITED', <String, dynamic>{'name': 'VIP'}),
      ),
    );
    final events = await ds.connectOnce('b1').toList();
    expect(events, hasLength(1));
    expect(
      events.single,
      const WaLabelCatalogChanged(
        waLabelId: '1000',
        name: 'VIP',
        color: 3,
        removed: false,
      ),
    );
  });

  test('label.wa.removed → WaLabelCatalogChanged(removed:true)', () async {
    stub(sse(waFrame('label.wa.removed', 'REMOVED')));
    final events = await ds.connectOnce('b1').toList();
    expect(
      events.single,
      const WaLabelCatalogChanged(
        waLabelId: '1000',
        name: '',
        color: 3,
        removed: true,
      ),
    );
  });

  test('label.wa.chat → WaChatLabelChanged', () async {
    stub(
      sse(
        waFrame('label.wa.chat', 'CHAT', <String, dynamic>{
          'chatLid': 'c1',
          'labeled': true,
        }),
      ),
    );
    final events = await ds.connectOnce('b1').toList();
    expect(
      events.single,
      const WaChatLabelChanged(
        waLabelId: '1000',
        chatLid: 'c1',
        color: 3,
        labeled: true,
      ),
    );
  });

  test('label.wa.message → WaMessageLabelChanged', () async {
    stub(
      sse(
        waFrame('label.wa.message', 'MESSAGE', <String, dynamic>{
          'chatLid': 'c1',
          'messageId': 'wamid.1',
        }),
      ),
    );
    final events = await ds.connectOnce('b1').toList();
    expect(
      events.single,
      const WaMessageLabelChanged(
        waLabelId: '1000',
        chatLid: 'c1',
        messageId: 'wamid.1',
        color: 3,
        labeled: false,
      ),
    );
  });

  test('ignora topics ajenos (mensajes, label.* interno)', () async {
    stub(
      sse(
        frame('message.inbound', '{"botId":"b1"}') +
            frame('label.assigned', '{"botId":"b1"}') +
            waFrame('label.wa.edited', 'EDITED', <String, dynamic>{
              'name': 'VIP',
            }),
      ),
    );
    final events = await ds.connectOnce('b1').toList();
    expect(events, hasLength(1));
    expect(events.single, isA<WaLabelCatalogChanged>());
  });

  test(
    'frame label.wa con JSON roto se omite sin derribar el stream',
    () async {
      stub(
        sse(
          frame('label.wa.edited', '{roto') +
              waFrame('label.wa.edited', 'EDITED', <String, dynamic>{
                'name': 'OK',
              }),
        ),
      );
      final events = await ds.connectOnce('b1').toList();
      expect(events, hasLength(1));
      expect((events.single as WaLabelCatalogChanged).name, 'OK');
    },
  );

  test(
    'kind desconocido en data se omite (mapper fail-loud, datasource soft)',
    () async {
      stub(sse(waFrame('label.wa.edited', 'ARCHIVED')));
      final events = await ds.connectOnce('b1').toList();
      expect(events, isEmpty);
    },
  );

  test('CHAT sin chatLid se omite (campos faltantes)', () async {
    stub(sse(waFrame('label.wa.chat', 'CHAT')));
    final events = await ds.connectOnce('b1').toList();
    expect(events, isEmpty);
  });

  test('pasa botId como query param y pide stream', () async {
    stub(
      sse(waFrame('label.wa.edited', 'EDITED', <String, dynamic>{'name': 'x'})),
    );
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
    expect((captured[1] as Map<String, dynamic>)['botId'], 'b1');
  });
}
