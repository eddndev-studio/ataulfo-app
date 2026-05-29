import 'package:ataulfo/features/messages/data/dto/message_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // El wire de httpmessages usa camelCase (externalId/chatLid/timestampMs),
  // a diferencia del snake_case de httpsessions. El DTO espeja ese contrato.
  Map<String, dynamic> msgJson({
    String externalId = 'e1',
    String chatLid = 'lid-1',
    String senderLid = 'alice',
    String kind = 'DM',
    String direction = 'INBOUND',
    String type = 'text',
    String content = 'hola',
    int timestampMs = 1700,
    String? mediaRef,
    String? quotedId,
    String? status,
  }) => <String, dynamic>{
    'externalId': externalId,
    'chatLid': chatLid,
    'senderLid': senderLid,
    'kind': kind,
    'direction': direction,
    'type': type,
    'content': content,
    'timestampMs': timestampMs,
    'mediaRef': ?mediaRef,
    'quotedId': ?quotedId,
    'status': ?status,
  };

  group('MessageResp.fromJson', () {
    test('OUTBOUND completo → todos los campos', () {
      final r = MessageResp.fromJson(
        msgJson(
          direction: 'OUTBOUND',
          status: 'SENT',
          mediaRef: 'ref-1',
          quotedId: 'e0',
        ),
      );
      expect(r.externalId, 'e1');
      expect(r.chatLid, 'lid-1');
      expect(r.senderLid, 'alice');
      expect(r.kind, 'DM');
      expect(r.direction, 'OUTBOUND');
      expect(r.type, 'text');
      expect(r.content, 'hola');
      expect(r.timestampMs, 1700);
      expect(r.mediaRef, 'ref-1');
      expect(r.quotedId, 'e0');
      expect(r.status, 'SENT');
    });

    test(
      'INBOUND sin omitempty (status/mediaRef/quotedId ausentes) → null',
      () {
        final r = MessageResp.fromJson(msgJson());
        expect(r.status, isNull);
        expect(r.mediaRef, isNull);
        expect(r.quotedId, isNull);
      },
    );

    test('content vacío es válido (no omitempty)', () {
      final r = MessageResp.fromJson(msgJson(content: ''));
      expect(r.content, '');
    });

    test('clave obligatoria ausente → FormatException', () {
      final bad = msgJson()..remove('chatLid');
      expect(() => MessageResp.fromJson(bad), throwsFormatException);
    });

    test('timestampMs no entero → FormatException', () {
      final bad = msgJson()..['timestampMs'] = 'no-num';
      expect(() => MessageResp.fromJson(bad), throwsFormatException);
    });
  });

  group('MessageThreadResp.fromJson', () {
    test('objeto {messages, prevCursor} → página con N mensajes', () {
      final page = MessageThreadResp.fromJson(<String, dynamic>{
        'messages': <dynamic>[
          msgJson(externalId: 'a'),
          msgJson(externalId: 'b'),
        ],
        'prevCursor': '1500:a',
      });
      expect(page.messages, hasLength(2));
      expect(page.messages[0].externalId, 'a');
      expect(page.prevCursor, '1500:a');
    });

    test('prevCursor ausente (omitempty) → null; messages [] → vacío', () {
      final page = MessageThreadResp.fromJson(<String, dynamic>{
        'messages': <dynamic>[],
      });
      expect(page.messages, isEmpty);
      expect(page.prevCursor, isNull);
    });

    test('messages ausente o no-lista → FormatException', () {
      expect(
        () => MessageThreadResp.fromJson(<String, dynamic>{'prevCursor': 'x'}),
        throwsFormatException,
      );
      expect(
        () => MessageThreadResp.fromJson(<String, dynamic>{'messages': 'nope'}),
        throwsFormatException,
      );
    });
  });
}
