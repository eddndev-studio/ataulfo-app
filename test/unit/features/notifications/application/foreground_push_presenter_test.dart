import 'dart:async';

import 'package:ataulfo/features/notifications/application/foreground_push_presenter.dart';
import 'package:ataulfo/features/notifications/domain/repositories/local_notifier.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalNotifier extends Mock implements LocalNotifier {}

void main() {
  late StreamController<RemoteMessage> messages;
  late _MockLocalNotifier notifier;
  late ForegroundPushPresenter presenter;

  setUp(() {
    messages = StreamController<RemoteMessage>();
    notifier = _MockLocalNotifier();
    when(
      () => notifier.show(
        title: any(named: 'title'),
        body: any(named: 'body'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
    presenter = ForegroundPushPresenter(
      messages: messages.stream,
      notifier: notifier,
    );
    presenter.start();
  });

  tearDown(() async {
    await presenter.dispose();
    await messages.close();
  });

  test(
    'un mensaje con notification se muestra como local notification',
    () async {
      messages.add(
        const RemoteMessage(
          notification: RemoteNotification(title: 'T', body: 'B'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      verify(
        () => notifier.show(
          title: 'T',
          body: 'B',
          payload: any(named: 'payload'),
        ),
      ).called(1);
    },
  );

  test(
    'el data del push viaja como payload JSON (para rutear el tap)',
    () async {
      messages.add(
        const RemoteMessage(
          notification: RemoteNotification(title: 'T', body: 'B'),
          data: {'eventType': 'message.inbound.new', 'botId': 'b1'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final captured =
          verify(
                () => notifier.show(
                  title: 'T',
                  body: 'B',
                  payload: captureAny(named: 'payload'),
                ),
              ).captured.single
              as String?;
      expect(captured, contains('"botId":"b1"'));
      expect(captured, contains('message.inbound.new'));
    },
  );

  test('un mensaje sin notification (solo data) no muestra nada', () async {
    messages.add(const RemoteMessage(data: {'k': 'v'}));
    await Future<void>.delayed(Duration.zero);

    verifyNever(
      () => notifier.show(
        title: any(named: 'title'),
        body: any(named: 'body'),
        payload: any(named: 'payload'),
      ),
    );
  });

  test(
    'una notification vacía (sin título ni cuerpo) no muestra nada',
    () async {
      messages.add(const RemoteMessage(notification: RemoteNotification()));
      await Future<void>.delayed(Duration.zero);

      verifyNever(
        () => notifier.show(
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      );
    },
  );
}
