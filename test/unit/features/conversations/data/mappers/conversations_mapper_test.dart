import 'package:ataulfo/features/conversations/data/dto/conversation_dto.dart';
import 'package:ataulfo/features/conversations/data/mappers/conversations_mapper.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

ConversationResp response({
  String botId = 'bot-1',
  String chatLid = 'lid-1',
  String kind = 'DM',
  String? phone = '5215550001',
  bool isArchived = false,
  bool isPinned = false,
  bool isMarkedUnread = false,
  String? mutedUntil,
  String? displayName,
  int unreadCount = 0,
  bool needsAttention = false,
  String? lastMessagePreview,
  String? lastMessageType,
  String? lastMessageDirection,
  int? lastMessageTimestampMs,
  String assistantId = 'assistant-1',
  String assistantName = 'Ventas',
  String channelName = 'Principal',
  String channelType = 'WA_UNOFFICIAL',
  String? channelIdentifier = '+52 1555 0001',
  List<ConversationLabelResp> labels = const <ConversationLabelResp>[],
}) => ConversationResp(
  botId: botId,
  chatLid: chatLid,
  kind: kind,
  phone: phone,
  isArchived: isArchived,
  isPinned: isPinned,
  isMarkedUnread: isMarkedUnread,
  mutedUntil: mutedUntil,
  displayName: displayName,
  unreadCount: unreadCount,
  needsAttention: needsAttention,
  lastMessagePreview: lastMessagePreview,
  lastMessageType: lastMessageType,
  lastMessageDirection: lastMessageDirection,
  lastMessageTimestampMs: lastMessageTimestampMs,
  assistantId: assistantId,
  assistantName: assistantName,
  channelName: channelName,
  channelType: channelType,
  channelIdentifier: channelIdentifier,
  labels: labels,
);

void main() {
  group('ConversationsMapper.respToEntity', () {
    test('mapea identidad, kind y muted_until', () {
      final entity = ConversationsMapper.respToEntity(
        response(
          chatLid: 'lid-dm',
          isArchived: true,
          isMarkedUnread: true,
          mutedUntil: '2026-06-01T12:00:00Z',
        ),
      );

      expect(entity.botId, 'bot-1');
      expect(entity.chatLid, 'lid-dm');
      expect(entity.kind, ConversationKind.dm);
      expect(entity.isArchived, isTrue);
      expect(entity.mutedUntil, DateTime.utc(2026, 6, 1, 12));
    });

    test('mapea actividad, procedencia, atención y etiquetas internas', () {
      final entity = ConversationsMapper.respToEntity(
        response(
          displayName: 'Alice',
          unreadCount: 4,
          needsAttention: true,
          lastMessagePreview: 'nos vemos',
          lastMessageType: 'text',
          lastMessageDirection: 'INBOUND',
          lastMessageTimestampMs: 1700000000000,
          labels: const <ConversationLabelResp>[
            ConversationLabelResp(id: 'vip', name: 'VIP', color: '#ff0000'),
          ],
        ),
      );

      expect(entity.displayName, 'Alice');
      expect(entity.unreadCount, 4);
      expect(entity.needsAttention, isTrue);
      expect(entity.lastMessagePreview, 'nos vemos');
      expect(entity.assistantName, 'Ventas');
      expect(entity.channelName, 'Principal');
      expect(entity.labels, const <ConversationLabel>[
        ConversationLabel(id: 'vip', name: 'VIP', color: '#ff0000'),
      ]);
    });

    test('GROUP sin phone ni actividad conserva nulos y defaults', () {
      final entity = ConversationsMapper.respToEntity(
        response(kind: 'GROUP', phone: null, channelIdentifier: null),
      );

      expect(entity.kind, ConversationKind.group);
      expect(entity.phone, isNull);
      expect(entity.unreadCount, 0);
      expect(entity.lastMessagePreview, isNull);
      expect(entity.channelIdentifier, isNull);
    });

    test('kind desconocido falla explícitamente', () {
      expect(
        () => ConversationsMapper.respToEntity(response(kind: 'CHANNEL')),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('muted_until malformado falla explícitamente', () {
      expect(
        () => ConversationsMapper.respToEntity(
          response(mutedUntil: 'no-es-fecha'),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
