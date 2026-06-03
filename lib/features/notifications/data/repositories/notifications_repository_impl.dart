import '../../domain/entities/notification_inbox_item.dart';
import '../../domain/entities/notification_preference.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_datasource.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({required NotificationsDatasource datasource})
    : _ds = datasource;

  final NotificationsDatasource _ds;

  @override
  Future<List<NotificationPreference>> listPreferences() =>
      _ds.listPreferences();

  @override
  Future<List<NotificationPreference>> savePreferences(
    List<NotificationPreference> preferences,
  ) => _ds.savePreferences(preferences);

  @override
  Future<List<NotificationInboxItem>> listInbox({required bool unreadOnly}) =>
      _ds.listInbox(unreadOnly: unreadOnly);

  @override
  Future<void> markRead(String id) => _ds.markRead(id);

  @override
  Future<void> markAllRead() => _ds.markAllRead();

  @override
  Future<void> registerPushToken({
    required String deviceId,
    required String fcmToken,
    required String platform,
  }) => _ds.registerPushToken(
    deviceId: deviceId,
    fcmToken: fcmToken,
    platform: platform,
  );

  @override
  Future<void> unregisterPushToken({required String deviceId}) =>
      _ds.unregisterPushToken(deviceId: deviceId);
}
