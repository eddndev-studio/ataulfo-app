import 'package:ataulfo/features/notifications/data/dto/notification_dto.dart';
import 'package:ataulfo/features/notifications/data/mappers/notification_mapper.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_inbox_item.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_preference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NotificationPreferenceResp maps backend wire to domain entity', () {
    final resp = NotificationPreferenceResp.fromJson(<String, dynamic>{
      'eventType': 'message.inbound.new',
      'enabled': true,
      'botFilter': <String, dynamic>{
        'all': false,
        'botIds': <String>['bot-1'],
      },
      'labelFilter': <String>['lbl-1'],
      'priority': 'high',
      'quietHours': <String, dynamic>{
        'start': '22:00',
        'end': '07:00',
        'timeZone': 'America/Belize',
      },
    });

    final entity = NotificationsMapper.preferenceRespToEntity(resp);

    expect(entity.eventType, NotificationEventType.messageInboundNew);
    expect(entity.botFilter.all, isFalse);
    expect(entity.botFilter.botIds, <String>['bot-1']);
    expect(entity.labelFilter, <String>['lbl-1']);
    expect(entity.priority, NotificationPriority.high);
    expect(entity.quietHours?.timeZone, 'America/Belize');
  });

  test('NotificationInboxResp maps unread item wire to domain entity', () {
    final resp = NotificationInboxResp.fromJson(<String, dynamic>{
      'id': 'ni-1',
      'eventType': 'flow.failed',
      'botId': 'bot-1',
      'chatLID': 'chat-1',
      'title': 'Flujo fallido',
      'body': 'send_failed',
      'priority': 'high',
      'payload': <String, dynamic>{'flowId': 'flow-1'},
      'coalesceKey': 'flow.failed:bot-1:chat-1',
      'count': 2,
      'status': 'UNREAD',
      'createdAt': '2026-06-03T12:00:00Z',
      'updatedAt': '2026-06-03T12:01:00Z',
    });

    final item = NotificationsMapper.inboxRespToEntity(resp);

    expect(item.id, 'ni-1');
    expect(item.eventType, NotificationEventType.flowFailed);
    expect(item.status, NotificationInboxStatus.unread);
    expect(item.payload, <String, String>{'flowId': 'flow-1'});
    expect(item.count, 2);
  });
}
