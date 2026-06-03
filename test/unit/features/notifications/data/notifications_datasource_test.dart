import 'package:ataulfo/features/notifications/data/datasources/notifications_datasource.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_preference.dart';
import 'package:ataulfo/features/notifications/domain/failures/notifications_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioNotificationsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioNotificationsDatasource(dio);
  });

  Response<Map<String, dynamic>> resp(String path, Map<String, dynamic> body) =>
      Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: body,
      );

  DioException badResponse(String path, int status) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('DioNotificationsDatasource.preferences', () {
    test('GET /notification-preferences retorna preferencias', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/notification-preferences'),
      ).thenAnswer(
        (_) async => resp('/notification-preferences', <String, dynamic>{
          'items': <dynamic>[
            <String, dynamic>{
              'eventType': 'message.inbound.new',
              'enabled': true,
              'botFilter': <String, dynamic>{'all': true, 'botIds': <String>[]},
              'labelFilter': <String>[],
              'priority': 'normal',
            },
          ],
        }),
      );

      final items = await ds.listPreferences();

      expect(items, hasLength(1));
      expect(items.single.eventType, NotificationEventType.messageInboundNew);
    });

    test('PUT /notification-preferences serializa preferences', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          '/notification-preferences',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => resp('/notification-preferences', <String, dynamic>{
          'items': <dynamic>[],
        }),
      );

      await ds.savePreferences(const <NotificationPreference>[
        NotificationPreference(
          eventType: NotificationEventType.botDisconnected,
          enabled: false,
          botFilter: NotificationBotFilter(all: true),
          labelFilter: <String>[],
          priority: NotificationPriority.high,
        ),
      ]);

      final captured =
          verify(
                () => dio.put<Map<String, dynamic>>(
                  '/notification-preferences',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      final prefs = captured['preferences'] as List<dynamic>;
      expect(prefs.single, containsPair('eventType', 'bot.disconnected'));
      expect(prefs.single, containsPair('enabled', false));
    });
  });

  group('DioNotificationsDatasource.inbox', () {
    test('GET /notifications?status=unread retorna inbox', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/notifications',
          queryParameters: <String, dynamic>{'status': 'unread'},
        ),
      ).thenAnswer(
        (_) async => resp('/notifications', <String, dynamic>{
          'items': <dynamic>[
            <String, dynamic>{
              'id': 'ni-1',
              'eventType': 'flow.failed',
              'title': 'Flujo fallido',
              'body': 'send_failed',
              'priority': 'high',
              'payload': <String, dynamic>{},
              'count': 1,
              'status': 'UNREAD',
              'createdAt': '2026-06-03T12:00:00Z',
              'updatedAt': '2026-06-03T12:00:00Z',
            },
          ],
        }),
      );

      final items = await ds.listInbox(unreadOnly: true);

      expect(items, hasLength(1));
      expect(items.single.id, 'ni-1');
      expect(items.single.isUnread, isTrue);
    });

    test('PUT /notifications/{id}/read marca una notificación', () async {
      when(() => dio.put<void>('/notifications/ni-1/read')).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/notifications/ni-1/read'),
          statusCode: 204,
        ),
      );

      await ds.markRead('ni-1');

      verify(() => dio.put<void>('/notifications/ni-1/read')).called(1);
    });

    test('PUT /notifications/read-all marca todas', () async {
      when(() => dio.put<void>('/notifications/read-all')).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/notifications/read-all'),
          statusCode: 204,
        ),
      );

      await ds.markAllRead();

      verify(() => dio.put<void>('/notifications/read-all')).called(1);
    });

    test('timeout → NotificationsTimeoutFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/notifications',
          queryParameters: <String, dynamic>{'status': 'unread'},
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/notifications'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        ds.listInbox(unreadOnly: true),
        throwsA(isA<NotificationsTimeoutFailure>()),
      );
    });

    test('422 → NotificationsInvalidFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/notification-preferences'),
      ).thenThrow(badResponse('/notification-preferences', 422));

      await expectLater(
        ds.listPreferences(),
        throwsA(isA<NotificationsInvalidFailure>()),
      );
    });
  });

  group('DioNotificationsDatasource.push', () {
    test(
      'POST /push/register serializa deviceId, fcmToken y platform',
      () async {
        when(
          () => dio.post<void>('/push/register', data: any(named: 'data')),
        ).thenAnswer(
          (_) async => Response<void>(
            requestOptions: RequestOptions(path: '/push/register'),
            statusCode: 204,
          ),
        );

        await ds.registerPushToken(
          deviceId: 'device-1',
          fcmToken: 'token-1',
          platform: 'android',
        );

        final captured =
            verify(
                  () => dio.post<void>(
                    '/push/register',
                    data: captureAny(named: 'data'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(captured, containsPair('deviceId', 'device-1'));
        expect(captured, containsPair('fcmToken', 'token-1'));
        expect(captured, containsPair('platform', 'android'));
      },
    );

    test('DELETE /push/token serializa deviceId', () async {
      when(
        () => dio.delete<void>('/push/token', data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/push/token'),
          statusCode: 204,
        ),
      );

      await ds.unregisterPushToken(deviceId: 'device-1');

      final captured =
          verify(
                () => dio.delete<void>(
                  '/push/token',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured, containsPair('deviceId', 'device-1'));
    });
  });
}
