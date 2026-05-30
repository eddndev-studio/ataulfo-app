import 'dart:convert';

import 'package:ataulfo/core/network/sse/sse_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper: un stream de bytes a partir de fragmentos de texto (cada string es
/// un "chunk" del transporte, para ejercer el corte arbitrario de la red).
Stream<List<int>> bytes(List<String> chunks) =>
    Stream<List<int>>.fromIterable(chunks.map(utf8.encode));

void main() {
  group('decodeSseEvents', () {
    test('un frame event+data → un SseEvent', () async {
      final got = await decodeSseEvents(
        bytes(['event: message.outbound\ndata: {"a":1}\n\n']),
      ).toList();

      expect(got, hasLength(1));
      expect(got.single.event, 'message.outbound');
      expect(got.single.data, '{"a":1}');
    });

    test('heartbeat (`: ping`) NO produce frame', () async {
      final got = await decodeSseEvents(bytes([': ping\n\n'])).toList();
      expect(got, isEmpty);
    });

    test('heartbeat seguido de frame → sólo el frame', () async {
      final got = await decodeSseEvents(
        bytes([': ping\n\nevent: message.inbound\ndata: {"x":true}\n\n']),
      ).toList();

      expect(got, hasLength(1));
      expect(got.single.event, 'message.inbound');
      expect(got.single.data, '{"x":true}');
    });

    test(
      'un frame partido a mitad de línea entre dos chunks → un frame',
      () async {
        // El corte cae dentro de la línea `data:` y del JSON.
        final got = await decodeSseEvents(
          bytes(['event: message.outbound\ndata: {"id":', '"w1"}\n\n']),
        ).toList();

        expect(got, hasLength(1));
        expect(got.single.event, 'message.outbound');
        expect(got.single.data, '{"id":"w1"}');
      },
    );

    test('dos frames en un solo chunk → dos eventos en orden', () async {
      final got = await decodeSseEvents(
        bytes([
          'event: message.inbound\ndata: {"n":1}\n\n'
              'event: message.outbound\ndata: {"n":2}\n\n',
        ]),
      ).toList();

      expect(got.map((e) => e.event).toList(), <String>[
        'message.inbound',
        'message.outbound',
      ]);
      expect(got.map((e) => e.data).toList(), <String>['{"n":1}', '{"n":2}']);
    });

    test('CRLF como fin de línea se maneja igual', () async {
      final got = await decodeSseEvents(
        bytes(['event: message.outbound\r\ndata: {"a":1}\r\n\r\n']),
      ).toList();

      expect(got, hasLength(1));
      expect(got.single.event, 'message.outbound');
      expect(got.single.data, '{"a":1}');
    });

    test('frame sin `data` (sólo event) NO se emite', () async {
      final got = await decodeSseEvents(
        bytes(['event: bot.session\n\n']),
      ).toList();
      expect(got, isEmpty);
    });

    test('sin línea `event:` → default "message"', () async {
      final got = await decodeSseEvents(bytes(['data: {"a":1}\n\n'])).toList();
      expect(got.single.event, 'message');
      expect(got.single.data, '{"a":1}');
    });
  });
}
