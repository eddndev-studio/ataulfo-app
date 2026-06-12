import 'package:ataulfo/features/notifications/data/datasources/notifications_datasource.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_preference.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _resp(String path, Map<String, dynamic> body) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: body,
    );

Map<String, dynamic> _pref(String eventType) => <String, dynamic>{
  'eventType': eventType,
  'enabled': true,
  'botFilter': <String, dynamic>{'all': true, 'botIds': <String>[]},
  'labelFilter': <String>[],
  'priority': 'normal',
};

void main() {
  late _MockDio dio;
  late DioNotificationsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioNotificationsDatasource(dio);
  });

  test('agent.alert parsea al enum nuevo', () async {
    when(
      () => dio.get<Map<String, dynamic>>('/notification-preferences'),
    ).thenAnswer(
      (_) async => _resp('/notification-preferences', <String, dynamic>{
        'items': <dynamic>[_pref('agent.alert')],
      }),
    );
    final items = await ds.listPreferences();
    expect(items.single.eventType, NotificationEventType.agentAlert);
  });

  test(
    'un eventType DESCONOCIDO se salta sin tumbar el resto de la lista',
    () async {
      when(
        () => dio.get<Map<String, dynamic>>('/notification-preferences'),
      ).thenAnswer(
        (_) async => _resp('/notification-preferences', <String, dynamic>{
          'items': <dynamic>[
            _pref('message.inbound.new'),
            _pref('algo.del.futuro'),
            _pref('flow.failed'),
          ],
        }),
      );
      final items = await ds.listPreferences();
      expect(items, hasLength(2));
      expect(
        items.map((p) => p.eventType),
        containsAll(<NotificationEventType>[
          NotificationEventType.messageInboundNew,
          NotificationEventType.flowFailed,
        ]),
      );
    },
  );
}
