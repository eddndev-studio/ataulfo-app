import 'dart:async';

import 'package:ataulfo/features/notifications/application/push_token_provider_resolver.dart';
import 'package:ataulfo/features/notifications/data/repositories/firebase_messaging_push_token_provider.dart';
import 'package:ataulfo/features/notifications/data/repositories/noop_push_token_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class _FakeNotificationSettings extends Fake implements NotificationSettings {}

void main() {
  late _MockFirebaseMessaging messaging;

  setUp(() {
    messaging = _MockFirebaseMessaging();
    when(
      () => messaging.requestPermission(),
    ).thenAnswer((_) async => _FakeNotificationSettings());
  });

  test('plataforma no-Android usa noop sin inicializar Firebase', () async {
    var initCalled = false;
    final resolver = PushTokenProviderResolver(
      isAndroid: false,
      initFirebase: () async => initCalled = true,
      messaging: () => messaging,
    );

    final provider = await resolver.resolve();

    expect(provider, isA<NoopPushTokenProvider>());
    expect(initCalled, isFalse, reason: 'no debe tocar Firebase fuera de Android');
  });

  test('Android con init OK usa el provider real y solicita permiso', () async {
    final resolver = PushTokenProviderResolver(
      isAndroid: true,
      initFirebase: () async {},
      messaging: () => messaging,
    );

    final provider = await resolver.resolve();

    expect(provider, isA<FirebaseMessagingPushTokenProvider>());
    verify(() => messaging.requestPermission()).called(1);
  });

  test('Android con init fallido cae a noop sin tumbar el arranque', () async {
    final resolver = PushTokenProviderResolver(
      isAndroid: true,
      initFirebase: () async => throw Exception('GMS ausente'),
      messaging: () => messaging,
    );

    final provider = await resolver.resolve();

    expect(provider, isA<NoopPushTokenProvider>());
  });

  test('resolve no se bloquea esperando la respuesta del permiso', () async {
    // El diálogo de permiso (Android 13+) puede tardar o no responderse nunca;
    // el arranque no debe quedar bloqueado por él.
    final pending = Completer<NotificationSettings>();
    when(
      () => messaging.requestPermission(),
    ).thenAnswer((_) => pending.future);
    final resolver = PushTokenProviderResolver(
      isAndroid: true,
      initFirebase: () async {},
      messaging: () => messaging,
    );

    final provider = await resolver.resolve().timeout(const Duration(seconds: 2));

    expect(provider, isA<FirebaseMessagingPushTokenProvider>());
    verify(() => messaging.requestPermission()).called(1);
  });

  test('un fallo al pedir permiso no impide usar el provider real', () async {
    when(
      () => messaging.requestPermission(),
    ).thenThrow(Exception('permiso rechazado'));
    final resolver = PushTokenProviderResolver(
      isAndroid: true,
      initFirebase: () async {},
      messaging: () => messaging,
    );

    final provider = await resolver.resolve();

    expect(provider, isA<FirebaseMessagingPushTokenProvider>());
  });
}
