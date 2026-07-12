import 'package:ataulfo/features/messages/data/dto/message_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('correccion', _correccionTests);
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
    String? mediaUrl,
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
    'mediaUrl': ?mediaUrl,
    'quotedId': ?quotedId,
    'status': ?status,
  };

  group('MessageResp.fromJson', () {
    test('OUTBOUND completo → todos los campos', () {
      final r = MessageResp.fromJson(
        msgJson(
          direction: 'OUTBOUND',
          status: 'SENT',
          type: 'image',
          mediaRef: 'ref-1',
          mediaUrl: 'https://cdn.example/signed?token=abc',
          quotedId: 'e0',
        ),
      );
      expect(r.externalId, 'e1');
      expect(r.chatLid, 'lid-1');
      expect(r.senderLid, 'alice');
      expect(r.kind, 'DM');
      expect(r.direction, 'OUTBOUND');
      expect(r.type, 'image');
      expect(r.content, 'hola');
      expect(r.timestampMs, 1700);
      expect(r.mediaRef, 'ref-1');
      expect(r.mediaUrl, 'https://cdn.example/signed?token=abc');
      expect(r.quotedId, 'e0');
      expect(r.status, 'SENT');
    });

    test(
      'INBOUND sin omitempty (status/mediaRef/mediaUrl/quotedId ausentes) → null',
      () {
        final r = MessageResp.fromJson(msgJson());
        expect(r.status, isNull);
        expect(r.mediaRef, isNull);
        expect(r.mediaUrl, isNull);
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

    // La Traza F0: el wire marca con `aiRunId` (omitempty) los OUTBOUND que
    // nacieron de una corrida de IA; ausente ⇒ '' (mensaje ajeno a la IA).
    test('aiRunId presente se parsea; ausente → vacío', () {
      final con = MessageResp.fromJson(
        msgJson(direction: 'OUTBOUND')..['aiRunId'] = 'run-7',
      );
      expect(con.aiRunId, 'run-7');
      final sin = MessageResp.fromJson(msgJson());
      expect(sin.aiRunId, '');
    });

    test('aiRunId no-string → FormatException', () {
      final bad = msgJson()..['aiRunId'] = 42;
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

// Los marcadores de corrección (editedAtMs/revokedAtMs) son claves aditivas
// omitempty: presentes se parsean, ausentes quedan null.
void _correccionTests() {
  Map<String, dynamic> base() => <String, dynamic>{
    'externalId': 'e1',
    'chatLid': 'lid-1',
    'senderLid': 'lid-1',
    'kind': 'DM',
    'direction': 'INBOUND',
    'type': 'text',
    'content': 'hola',
    'timestampMs': 1700,
  };

  test('editedAtMs/revokedAtMs presentes se parsean', () {
    final j = base()
      ..['editedAtMs'] = 111
      ..['revokedAtMs'] = 222;
    final dto = MessageResp.fromJson(j);
    expect(dto.editedAtMs, 111);
    expect(dto.revokedAtMs, 222);
  });

  test('ausentes quedan null (backend previo al campo)', () {
    final dto = MessageResp.fromJson(base());
    expect(dto.editedAtMs, isNull);
    expect(dto.revokedAtMs, isNull);
  });
}
