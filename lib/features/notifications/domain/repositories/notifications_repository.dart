import '../entities/notification_inbox_item.dart';
import '../entities/notification_preference.dart';

abstract interface class NotificationsRepository {
  Future<List<NotificationPreference>> listPreferences();

  Future<List<NotificationPreference>> savePreferences(
    List<NotificationPreference> preferences,
  );

  Future<List<NotificationInboxItem>> listInbox({required bool unreadOnly});

  Future<void> markRead(String id);

  Future<void> markAllRead();

  Future<void> registerPushToken({
    required String deviceId,
    required String fcmToken,
    required String platform,
  });

  Future<void> unregisterPushToken({required String deviceId});
}
