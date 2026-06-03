import 'package:ataulfo/features/notifications/data/datasources/notifications_datasource.dart';
import 'package:ataulfo/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements NotificationsDatasource {}

void main() {
  late _MockDatasource ds;
  late NotificationsRepositoryImpl repo;

  setUp(() {
    ds = _MockDatasource();
    repo = NotificationsRepositoryImpl(datasource: ds);
  });

  group('NotificationsRepositoryImpl.push', () {
    test('registerPushToken delega al datasource', () async {
      when(
        () => ds.registerPushToken(
          deviceId: any(named: 'deviceId'),
          fcmToken: any(named: 'fcmToken'),
          platform: any(named: 'platform'),
        ),
      ).thenAnswer((_) async {});

      await repo.registerPushToken(
        deviceId: 'device-1',
        fcmToken: 'token-1',
        platform: 'android',
      );

      verify(
        () => ds.registerPushToken(
          deviceId: 'device-1',
          fcmToken: 'token-1',
          platform: 'android',
        ),
      ).called(1);
    });

    test('unregisterPushToken delega al datasource', () async {
      when(
        () => ds.unregisterPushToken(deviceId: any(named: 'deviceId')),
      ).thenAnswer((_) async {});

      await repo.unregisterPushToken(deviceId: 'device-1');

      verify(() => ds.unregisterPushToken(deviceId: 'device-1')).called(1);
    });
  });
}
