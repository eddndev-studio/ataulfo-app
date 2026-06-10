import 'dart:async';

import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/notifications/application/push_tap_coordinator.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _identity = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
);

void main() {
  late _MockAuthBloc auth;
  late StreamController<Map<String, Object?>> taps;
  late List<String> navigated;

  setUp(() {
    auth = _MockAuthBloc();
    taps = StreamController<Map<String, Object?>>();
    navigated = <String>[];
  });

  tearDown(() => taps.close());

  PushTapCoordinator build({
    Future<Map<String, Object?>?> Function()? initialTap,
  }) => PushTapCoordinator(
    authBloc: auth,
    taps: taps.stream,
    initialTap: initialTap ?? () async => null,
    navigate: navigated.add,
  );

  test('tap con sesión activa navega a la ruta del payload', () async {
    when(() => auth.state).thenReturn(const AuthAuthenticated(_identity));
    final c = build();
    await c.start();

    taps.add(<String, Object?>{
      'eventType': 'message.inbound.new',
      'botId': 'b1',
    });
    await Future<void>.delayed(Duration.zero);

    expect(navigated, <String>['/bots/b1/sessions']);
    await c.dispose();
  });

  test('cold start: el tap inicial espera la sesión y navega', () async {
    // Al abrir desde la bandeja con la app muerta, el auth-check aún corre:
    // la navegación debe esperar a Authenticated para que el redirect del
    // router no se trague el destino.
    whenListen(
      auth,
      Stream<AuthState>.fromIterable(const <AuthState>[
        AuthAuthenticated(_identity),
      ]),
      initialState: const AuthInitial(),
    );
    final c = build(
      initialTap: () async => <String, Object?>{
        'eventType': 'bot.disconnected',
        'botId': 'b2',
      },
    );
    await c.start();
    await Future<void>.delayed(Duration.zero);

    expect(navigated, <String>['/bots/b2/connect']);
    await c.dispose();
  });

  test('sin sesión (Unauthenticated) el tap se descarta', () async {
    whenListen(
      auth,
      Stream<AuthState>.fromIterable(const <AuthState>[AuthUnauthenticated()]),
      initialState: const AuthInitial(),
    );
    final c = build(
      initialTap: () async => <String, Object?>{
        'eventType': 'message.inbound.new',
        'botId': 'b1',
      },
    );
    await c.start();
    await Future<void>.delayed(Duration.zero);

    expect(navigated, isEmpty);
    await c.dispose();
  });

  test('start es idempotente (no duplica navegaciones)', () async {
    when(() => auth.state).thenReturn(const AuthAuthenticated(_identity));
    final c = build();
    await c.start();
    await c.start();

    taps.add(<String, Object?>{'eventType': 'flow.failed', 'botId': 'b3'});
    await Future<void>.delayed(Duration.zero);

    expect(navigated, <String>['/bots/b3']);
    await c.dispose();
  });
}
