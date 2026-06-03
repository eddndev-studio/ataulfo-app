import 'package:ataulfo/features/notifications/domain/entities/notification_inbox_item.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_preference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationPreference', () {
    test('equality compares nested filters and quiet hours', () {
      const pref = NotificationPreference(
        eventType: NotificationEventType.messageInboundNew,
        enabled: true,
        botFilter: NotificationBotFilter(all: false, botIds: <String>['b1']),
        labelFilter: <String>['l1'],
        priority: NotificationPriority.high,
        quietHours: NotificationQuietHours(
          start: '22:00',
          end: '07:00',
          timeZone: 'America/Belize',
        ),
      );

      expect(pref, equals(pref.copyWith()));
      expect(
        pref,
        isNot(
          equals(
            pref.copyWith(
              botFilter: const NotificationBotFilter(
                all: true,
                botIds: <String>[],
              ),
            ),
          ),
        ),
      );
    });
  });

  group('NotificationInboxItem', () {
    test('unread/read helpers follow status', () {
      final unread = NotificationInboxItem(
        id: 'ni-1',
        eventType: NotificationEventType.flowFailed,
        title: 'Flujo fallido',
        body: 'send_failed',
        priority: NotificationPriority.high,
        count: 2,
        status: NotificationInboxStatus.unread,
        createdAt: DateTime.utc(2026, 6, 3, 12),
        updatedAt: DateTime.utc(2026, 6, 3, 12),
      );

      expect(unread.isUnread, isTrue);
      expect(
        unread.copyWith(status: NotificationInboxStatus.read).isUnread,
        isFalse,
      );
    });
  });
}
