import 'dart:async';

import 'package:ataulfo/core/storage/device_id_provider.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/notifications/application/push_registration_coordinator.dart';
import 'package:ataulfo/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:ataulfo/features/notifications/domain/repositories/push_token_provider.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockNotificationsRepo extends Mock implements NotificationsRepository {}

class _MockDeviceIdProvider extends Mock implements DeviceIdProvider {}

class _MockPushTokenProvider extends Mock implements PushTokenProvider {}

const _identity = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
);

void main() {
  late _MockAuthBloc authBloc;
  late _MockNotificationsRepo repo;
  late _MockDeviceIdProvider deviceIds;
  late _MockPushTokenProvider tokens;
  late StreamController<String> tokenRefreshes;

  setUp(() {
    authBloc = _MockAuthBloc();
    repo = _MockNotificationsRepo();
    deviceIds = _MockDeviceIdProvider();
    tokens = _MockPushTokenProvider();
    tokenRefreshes = StreamController<String>();

    when(deviceIds.getOrCreate).thenAnswer((_) async => 'device-1');
    when(tokens.currentToken).thenAnswer((_) async => 'token-1');
    when(() => tokens.tokenRefreshes).thenAnswer((_) => tokenRefreshes.stream);
    when(
      () => repo.registerPushToken(
        deviceId: any(named: 'deviceId'),
        fcmToken: any(named: 'fcmToken'),
        platform: any(named: 'platform'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.unregisterPushToken(deviceId: any(named: 'deviceId')),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await tokenRefreshes.close();
  });

  PushRegistrationCoordinator coordinator() => PushRegistrationCoordinator(
    authBloc: authBloc,
    repository: repo,
    deviceIds: deviceIds,
    tokens: tokens,
  );

  test('start con AuthAuthenticated registra el token actual', () async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    whenListen<AuthState>(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthAuthenticated(_identity),
    );

    final c = coordinator();
    await c.start();
    await c.dispose();

    verify(
      () => repo.registerPushToken(
        deviceId: 'device-1',
        fcmToken: 'token-1',
        platform: 'android',
      ),
    ).called(1);
  });

  test('logout tras sesión autenticada desregistra device', () async {
    final authStates = StreamController<AuthState>();
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    whenListen<AuthState>(
      authBloc,
      authStates.stream,
      initialState: const AuthAuthenticated(_identity),
    );

    final c = coordinator();
    await c.start();
    authStates.add(const AuthUnauthenticated());
    await Future<void>.delayed(Duration.zero);
    await c.dispose();
    await authStates.close();

    verify(() => repo.unregisterPushToken(deviceId: 'device-1')).called(1);
  });

  test(
    'token refresh con sesión autenticada registra el token nuevo',
    () async {
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
      whenListen<AuthState>(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(_identity),
      );

      final c = coordinator();
      await c.start();
      clearInteractions(repo);

      tokenRefreshes.add('token-2');
      await Future<void>.delayed(Duration.zero);
      await c.dispose();

      verify(
        () => repo.registerPushToken(
          deviceId: 'device-1',
          fcmToken: 'token-2',
          platform: 'android',
        ),
      ).called(1);
    },
  );

  test('token nulo no registra', () async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    when(tokens.currentToken).thenAnswer((_) async => null);
    whenListen<AuthState>(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthAuthenticated(_identity),
    );

    final c = coordinator();
    await c.start();
    await c.dispose();

    verifyNever(
      () => repo.registerPushToken(
        deviceId: any(named: 'deviceId'),
        fcmToken: any(named: 'fcmToken'),
        platform: any(named: 'platform'),
      ),
    );
  });
}
