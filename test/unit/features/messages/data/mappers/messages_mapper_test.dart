import 'package:ataulfo/features/messages/data/dto/message_dto.dart';
import 'package:ataulfo/features/messages/data/mappers/messages_mapper.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MessageResp resp({
    String kind = 'GROUP',
    String direction = 'OUTBOUND',
    String? status = 'READ',
    String type = 'text',
    String? mediaUrl,
    String aiRunId = '',
  }) => MessageResp(
    externalId: 'e1',
    chatLid: 'grupo-1',
    senderLid: 'bot',
    kind: kind,
    direction: direction,
    type: type,
    content: 'ey',
    timestampMs: 1800,
    mediaRef: null,
    mediaUrl: mediaUrl,
    quotedId: null,
    status: status,
    aiRunId: aiRunId,
  );

  group('MessagesMapper.respToMessage', () {
    test('mapea kind/direction/status vía fromWire', () {
      final m = MessagesMapper.respToMessage(resp());
      expect(m.kind, MessageKind.group);
      expect(m.direction, MessageDirection.outbound);
      expect(m.status, MessageStatus.read);
      expect(m.content, 'ey');
    });

    test('status ausente (INBOUND) → null', () {
      final m = MessagesMapper.respToMessage(
        resp(direction: 'INBOUND', status: null),
      );
      expect(m.status, isNull);
    });

    test('mediaUrl firmada pasa al dominio tal cual', () {
      final m = MessagesMapper.respToMessage(
        resp(type: 'image', mediaUrl: 'https://cdn/x?token=1'),
      );
      expect(m.mediaUrl, 'https://cdn/x?token=1');
    });

    test('kind desconocido → ArgumentError (propaga fail-loud)', () {
      expect(
        () => MessagesMapper.respToMessage(resp(kind: 'CHANNEL')),
        throwsArgumentError,
      );
    });

    test('aiRunId del wire pasa al dominio (default vacío)', () {
      expect(MessagesMapper.respToMessage(resp()).aiRunId, '');
      expect(
        MessagesMapper.respToMessage(resp(aiRunId: 'run-9')).aiRunId,
        'run-9',
      );
    });
  });

  group('MessagesMapper.respToPage', () {
    test('mapea mensajes + prevCursor', () {
      final page = MessagesMapper.respToPage(
        MessageThreadResp(messages: <MessageResp>[resp()], prevCursor: '1:e0'),
      );
      expect(page.messages, hasLength(1));
      expect(page.messages[0].kind, MessageKind.group);
      expect(page.prevCursor, '1:e0');
    });
  });
}
