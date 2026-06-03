import '../../domain/entities/notification_inbox_item.dart';
import '../../domain/entities/notification_preference.dart';
import '../dto/notification_dto.dart';

class NotificationsMapper {
  const NotificationsMapper._();

  static NotificationPreference preferenceRespToEntity(
    NotificationPreferenceResp resp,
  ) => NotificationPreference(
    eventType: NotificationEventType.fromWire(resp.eventType),
    enabled: resp.enabled,
    botFilter: NotificationBotFilter(
      all: resp.botFilter.all,
      botIds: resp.botFilter.botIds,
    ),
    labelFilter: resp.labelFilter,
    priority: NotificationPriority.fromWire(resp.priority),
    quietHours: resp.quietHours == null
        ? null
        : NotificationQuietHours(
            start: resp.quietHours!.start,
            end: resp.quietHours!.end,
            timeZone: resp.quietHours!.timeZone,
          ),
  );

  static NotificationInboxItem inboxRespToEntity(NotificationInboxResp resp) =>
      NotificationInboxItem(
        id: resp.id,
        eventType: NotificationEventType.fromWire(resp.eventType),
        botId: resp.botId,
        chatLid: resp.chatLid,
        labelId: resp.labelId,
        title: resp.title,
        body: resp.body,
        priority: NotificationPriority.fromWire(resp.priority),
        payload: resp.payload,
        coalesceKey: resp.coalesceKey,
        count: resp.count,
        status: NotificationInboxStatus.fromWire(resp.status),
        createdAt: DateTime.parse(resp.createdAt),
        updatedAt: DateTime.parse(resp.updatedAt),
        readAt: resp.readAt == null ? null : DateTime.parse(resp.readAt!),
      );

  static Map<String, dynamic> preferenceToWire(NotificationPreference pref) {
    final quiet = pref.quietHours;
    return <String, dynamic>{
      'eventType': pref.eventType.wire,
      'enabled': pref.enabled,
      'botFilter': <String, dynamic>{
        'all': pref.botFilter.all,
        'botIds': pref.botFilter.botIds,
      },
      'labelFilter': pref.labelFilter,
      'priority': pref.priority.wire,
      if (quiet != null)
        'quietHours': <String, dynamic>{
          'start': quiet.start,
          'end': quiet.end,
          'timeZone': quiet.timeZone,
        },
    };
  }
}
