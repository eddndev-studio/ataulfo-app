import 'dart:async';

import 'package:ataulfo/core/storage/device_id_provider.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/notifications/application/push_registration_coordinator.dart';
import 'package:ataulfo/features/notifications/domain/failures/notifications_failure.dart';
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

  test(
    'logout NO desregistra reactivamente (lo hace el hook de logout con Bearer vivo)',
    () async {
      // El desregistro del device se dispara desde el use-case de logout,
      // ANTES de purgar la sesión, para que el DELETE viaje con Bearer. Si el
      // coordinator lo repitiera al ver AuthUnauthenticated, ese segundo DELETE
      // iría sin token (storage ya limpio) → 401. Por eso el path reactivo no
      // debe tocar el repo.
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

      verifyNever(
        () => repo.unregisterPushToken(deviceId: any(named: 'deviceId')),
      );
    },
  );

  test(
    'unregisterForLogout desregistra el device y no relanza si el repo falla',
    () async {
      when(() => authBloc.state).thenReturn(const AuthInitial());
      whenListen<AuthState>(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthInitial(),
      );
      final c = coordinator();
      await c.start();
      when(
        () => repo.unregisterPushToken(deviceId: any(named: 'deviceId')),
      ).thenAnswer((_) async => throw const NotificationsNetworkFailure());

      // No debe propagar el fallo del repo (best-effort).
      await c.unregisterForLogout();
      await c.dispose();

      verify(() => repo.unregisterPushToken(deviceId: 'device-1')).called(1);
    },
  );

  test(
    'registerPushToken que lanza no rompe el listener del stream de auth',
    () async {
      final authStates = StreamController<AuthState>();
      when(() => authBloc.state).thenReturn(const AuthInitial());
      whenListen<AuthState>(
        authBloc,
        authStates.stream,
        initialState: const AuthInitial(),
      );
      when(
        () => repo.registerPushToken(
          deviceId: any(named: 'deviceId'),
          fcmToken: any(named: 'fcmToken'),
          platform: any(named: 'platform'),
        ),
      ).thenAnswer((_) async => throw const NotificationsNetworkFailure());

      final c = coordinator();
      await c.start();

      // La primera transición a autenticado dispara un register que lanza; el
      // coordinator debe absorberlo sin romper el stream.
      authStates.add(const AuthAuthenticated(_identity));
      await Future<void>.delayed(Duration.zero);

      // El stream sigue vivo: una segunda transición se sigue procesando.
      clearInteractions(repo);
      when(
        () => repo.registerPushToken(
          deviceId: any(named: 'deviceId'),
          fcmToken: any(named: 'fcmToken'),
          platform: any(named: 'platform'),
        ),
      ).thenAnswer((_) async {});
      tokenRefreshes.add('token-3');
      await Future<void>.delayed(Duration.zero);
      await c.dispose();
      await authStates.close();

      verify(
        () => repo.registerPushToken(
          deviceId: 'device-1',
          fcmToken: 'token-3',
          platform: 'android',
        ),
      ).called(1);
    },
  );

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
