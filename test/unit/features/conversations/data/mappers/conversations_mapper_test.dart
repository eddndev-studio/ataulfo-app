import 'package:ataulfo/features/conversations/data/dto/conversation_dto.dart';
import 'package:ataulfo/features/conversations/data/mappers/conversations_mapper.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConversationsMapper.respToEntity', () {
    test('DM con muted_until → entidad con DateTime parseado', () {
      const resp = ConversationResp(
        chatLid: 'lid-dm',
        kind: 'DM',
        phone: '5215550001',
        isArchived: true,
        isPinned: false,
        isMarkedUnread: true,
        mutedUntil: '2026-06-01T12:00:00Z',
      );
      final c = ConversationsMapper.respToEntity(resp);
      expect(c.chatLid, 'lid-dm');
      expect(c.kind, ConversationKind.dm);
      expect(c.phone, '5215550001');
      expect(c.isArchived, isTrue);
      expect(c.mutedUntil, DateTime.utc(2026, 6, 1, 12));
    });

    test('GROUP sin phone ni muted → phone/mutedUntil null', () {
      const resp = ConversationResp(
        chatLid: 'lid-grp',
        kind: 'GROUP',
        phone: null,
        isArchived: false,
        isPinned: true,
        isMarkedUnread: false,
        mutedUntil: null,
      );
      final c = ConversationsMapper.respToEntity(resp);
      expect(c.kind, ConversationKind.group);
      expect(c.phone, isNull);
      expect(c.mutedUntil, isNull);
      expect(c.isPinned, isTrue);
    });

    test('kind desconocido → ArgumentError (fail-loud, propaga)', () {
      const resp = ConversationResp(
        chatLid: 'x',
        kind: 'CHANNEL',
        phone: null,
        isArchived: false,
        isPinned: false,
        isMarkedUnread: false,
        mutedUntil: null,
      );
      expect(
        () => ConversationsMapper.respToEntity(resp),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('muted_until malformado → FormatException', () {
      const resp = ConversationResp(
        chatLid: 'x',
        kind: 'DM',
        phone: '1',
        isArchived: false,
        isPinned: false,
        isMarkedUnread: false,
        mutedUntil: 'no-es-fecha',
      );
      expect(
        () => ConversationsMapper.respToEntity(resp),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
