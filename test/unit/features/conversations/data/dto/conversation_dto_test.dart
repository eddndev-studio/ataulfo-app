import 'package:ataulfo/features/conversations/data/dto/conversation_dto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> itemJson({String botId = 'bot-1'}) => <String, dynamic>{
  'bot_id': botId,
  'chat_lid': 'lid-1',
  'kind': 'DM',
  'phone': '+502 5555 9012',
  'display_name': 'Comercial Rivera',
  'is_archived': false,
  'is_pinned': true,
  'is_marked_unread': false,
  'unread_count': 3,
  'needs_attention': true,
  'last_message_preview': '¿Me confirma la entrega?',
  'last_message_type': 'text',
  'last_message_direction': 'INBOUND',
  'last_message_timestamp_ms': 1770000000000,
  'assistant_id': 'assistant-1',
  'assistant_name': 'Ventas regionales',
  'channel_name': 'Ventas Guatemala',
  'channel_type': 'WA_UNOFFICIAL',
  'channel_identifier': '+502 2440 9012',
  'labels': <Map<String, dynamic>>[
    <String, dynamic>{'id': 'vip', 'name': 'VIP', 'color': '#C57B57'},
  ],
};

void main() {
  group('ConversationsPageResp.fromJson', () {
    test('parsea página org-scoped con procedencia, atención y labels', () {
      final page = ConversationsPageResp.fromJson(<String, dynamic>{
        'items': <Map<String, dynamic>>[itemJson()],
        'next_cursor': 'opaque-next',
      });

      expect(page.nextCursor, 'opaque-next');
      expect(page.items, hasLength(1));
      final row = page.items.single;
      expect(row.botId, 'bot-1');
      expect(row.needsAttention, isTrue);
      expect(row.assistantName, 'Ventas regionales');
      expect(row.channelName, 'Ventas Guatemala');
      expect(row.channelIdentifier, '+502 2440 9012');
      expect(row.labels.single.id, 'vip');
      expect(row.labels.single.color, '#C57B57');
    });

    test('items vacío y cursor omitido son válidos', () {
      final page = ConversationsPageResp.fromJson(<String, dynamic>{
        'items': <dynamic>[],
      });

      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('bot_id obligatorio evita colapsar chats iguales entre canales', () {
      final malformed = itemJson()..remove('bot_id');

      expect(
        () => ConversationsPageResp.fromJson(<String, dynamic>{
          'items': <Map<String, dynamic>>[malformed],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('labels malformadas fallan fuerte', () {
      final malformed = itemJson()
        ..['labels'] = <dynamic>[
          <String, dynamic>{'id': 'vip', 'name': 'VIP'},
        ];

      expect(
        () => ConversationsPageResp.fromJson(<String, dynamic>{
          'items': <Map<String, dynamic>>[malformed],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('next_cursor no String falla fuerte', () {
      expect(
        () => ConversationsPageResp.fromJson(<String, dynamic>{
          'items': <dynamic>[],
          'next_cursor': 17,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
