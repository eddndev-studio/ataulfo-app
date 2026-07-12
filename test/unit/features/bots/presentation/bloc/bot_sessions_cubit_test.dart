import 'dart:async';
import 'dart:math' as math;

import 'package:ataulfo/features/bots/domain/entities/connect_link.dart';
import 'package:ataulfo/features/bots/domain/entities/session_status.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/domain/repositories/bot_session_repository.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_sessions_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repo con compuertas por bot: el test decide cuándo (y cómo) resuelve cada
/// `getSessionState`, para observar el poblado incremental y el fail-soft.
class _GatedRepo implements BotSessionRepository {
  final Map<String, Completer<SessionStatus>> _gates =
      <String, Completer<SessionStatus>>{};

  Completer<SessionStatus> _gate(String id) =>
      _gates.putIfAbsent(id, () => Completer<SessionStatus>());

  @override
  Future<SessionStatus> getSessionState(String botId) => _gate(botId).future;

  void complete(String id, SessionState state) {
    final g = _gate(id);
    if (!g.isCompleted) g.complete(SessionStatus(state: state));
  }

  void fail(String id, BotsFailure failure) {
    final g = _gate(id);
    if (!g.isCompleted) g.completeError(failure);
  }

  /// Descarta las compuertas para un nuevo round (refresh).
  void reset() => _gates.clear();

  @override
  Future<void> startSession(String botId) => throw UnimplementedError();
  @override
  Future<void> stopSession(String botId) => throw UnimplementedError();
  @override
  Future<ConnectLink> issueConnectLink(String botId) =>
      throw UnimplementedError();
  @override
  Future<void> clearConversations(String botId) => throw UnimplementedError();
  @override
  Future<void> resetSessions(String botId) => throw UnimplementedError();
  @override
  Future<void> wipeCredentials(String botId) => throw UnimplementedError();
  @override
  Future<String> pairPhone(String botId, String phone) =>
      throw UnimplementedError();
}

/// Repo que cuenta cuántas consultas corren en simultáneo, para verificar la
/// cota de concurrencia del abanico.
class _CountingRepo implements BotSessionRepository {
  _CountingRepo(this._states);

  final Map<String, SessionState> _states;
  int _inFlight = 0;
  int maxInFlight = 0;
  final List<String> queried = <String>[];

  @override
  Future<SessionStatus> getSessionState(String botId) async {
    queried.add(botId);
    _inFlight++;
    maxInFlight = math.max(maxInFlight, _inFlight);
    // Ceder el turno hace que las consultas admitidas se solapen: sin cota,
    // arrancarían todas a la vez.
    await Future<void>.delayed(Duration.zero);
    _inFlight--;
    final s = _states[botId];
    if (s == null) throw const BotsNetworkFailure();
    return SessionStatus(state: s);
  }

  @override
  Future<void> startSession(String botId) => throw UnimplementedError();
  @override
  Future<void> stopSession(String botId) => throw UnimplementedError();
  @override
  Future<ConnectLink> issueConnectLink(String botId) =>
      throw UnimplementedError();
  @override
  Future<void> clearConversations(String botId) => throw UnimplementedError();
  @override
  Future<void> resetSessions(String botId) => throw UnimplementedError();
  @override
  Future<void> wipeCredentials(String botId) => throw UnimplementedError();
  @override
  Future<String> pairPhone(String botId, String phone) =>
      throw UnimplementedError();
}

void main() {
  test('estado inicial vacío: stateFor devuelve null para todo bot', () {
    final cubit = BotSessionsCubit(_GatedRepo());
    expect(cubit.state.stateFor('b1'), isNull);
    cubit.close();
  });

  test('puebla el estado por bot conforme llega cada resultado', () async {
    final repo = _GatedRepo();
    final cubit = BotSessionsCubit(repo);

    final future = cubit.load(<String>['b1', 'b2']);

    // b2 resuelve primero: su estado aparece sin esperar a b1.
    repo.complete('b2', SessionState.disconnected);
    await pumpEventQueue();
    expect(cubit.state.stateFor('b2'), SessionState.disconnected);
    expect(cubit.state.stateFor('b1'), isNull);

    repo.complete('b1', SessionState.connected);
    await future;
    expect(cubit.state.stateFor('b1'), SessionState.connected);
    expect(cubit.state.stateFor('b2'), SessionState.disconnected);

    await cubit.close();
  });

  test('un fetch fallido no inventa estado (fail-soft por bot)', () async {
    final repo = _GatedRepo();
    final cubit = BotSessionsCubit(repo);

    final future = cubit.load(<String>['b1', 'b2']);
    repo.fail('b1', const BotsNetworkFailure());
    repo.complete('b2', SessionState.connected);
    await future;

    expect(cubit.state.stateFor('b1'), isNull);
    expect(cubit.state.stateFor('b2'), SessionState.connected);

    await cubit.close();
  });

  test('refresh: un tick fallido NO degrada el último estado bueno', () async {
    final repo = _GatedRepo();
    final cubit = BotSessionsCubit(repo);

    final first = cubit.load(<String>['b1']);
    repo.complete('b1', SessionState.connected);
    await first;
    expect(cubit.state.stateFor('b1'), SessionState.connected);

    repo.reset();
    final second = cubit.load(<String>['b1']);
    repo.fail('b1', const BotsNetworkFailure());
    await second;

    // Conserva el CONNECTED previo: un fallo transitorio no falsea desconexión.
    expect(cubit.state.stateFor('b1'), SessionState.connected);

    await cubit.close();
  });

  test('refresh poda los bots que ya no están en la lista', () async {
    final repo = _GatedRepo();
    final cubit = BotSessionsCubit(repo);

    final first = cubit.load(<String>['b1', 'b2']);
    repo.complete('b1', SessionState.connected);
    repo.complete('b2', SessionState.disconnected);
    await first;
    expect(cubit.state.stateFor('b2'), SessionState.disconnected);

    repo.reset();
    final second = cubit.load(<String>['b1']);
    repo.complete('b1', SessionState.connected);
    await second;

    expect(cubit.state.stateFor('b1'), SessionState.connected);
    expect(cubit.state.stateFor('b2'), isNull);

    await cubit.close();
  });

  test('acota la concurrencia del abanico', () async {
    final repo = _CountingRepo(<String, SessionState>{
      'b1': SessionState.connected,
      'b2': SessionState.connected,
      'b3': SessionState.connected,
      'b4': SessionState.connected,
      'b5': SessionState.connected,
      'b6': SessionState.connected,
    });
    final cubit = BotSessionsCubit(repo);

    await cubit.load(<String>['b1', 'b2', 'b3', 'b4', 'b5', 'b6']);

    expect(repo.queried.length, 6);
    // Corre en paralelo (cota > 1) pero acotado (nunca las 6 a la vez).
    expect(repo.maxInFlight, greaterThan(1));
    expect(repo.maxInFlight, lessThanOrEqualTo(4));
    expect(cubit.state.stateFor('b6'), SessionState.connected);

    await cubit.close();
  });

  test('load con lista vacía deja el estado vacío', () async {
    final cubit = BotSessionsCubit(_GatedRepo());
    await cubit.load(<String>[]);
    expect(cubit.state.stateFor('b1'), isNull);
    await cubit.close();
  });
}
