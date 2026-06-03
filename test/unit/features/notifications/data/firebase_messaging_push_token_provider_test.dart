import 'package:ataulfo/features/notifications/data/repositories/firebase_messaging_push_token_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

void main() {
  late _MockFirebaseMessaging messaging;
  late FirebaseMessagingPushTokenProvider provider;

  setUp(() {
    messaging = _MockFirebaseMessaging();
    provider = FirebaseMessagingPushTokenProvider(messaging);
  });

  test('currentToken delega en FirebaseMessaging.getToken', () async {
    when(() => messaging.getToken()).thenAnswer((_) async => 'fcm-abc');

    expect(await provider.currentToken(), 'fcm-abc');
    verify(() => messaging.getToken()).called(1);
  });

  test('currentToken propaga null cuando aún no hay token', () async {
    when(() => messaging.getToken()).thenAnswer((_) async => null);

    expect(await provider.currentToken(), isNull);
  });

  test('tokenRefreshes reemite el stream onTokenRefresh', () {
    when(
      () => messaging.onTokenRefresh,
    ).thenAnswer((_) => Stream<String>.fromIterable(['t1', 't2']));

    expect(provider.tokenRefreshes, emitsInOrder(['t1', 't2']));
  });
}
