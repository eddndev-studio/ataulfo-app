import 'dart:async';

import 'package:ataulfo/features/bots/domain/entities/connect_link.dart';
import 'package:ataulfo/features/bots/domain/entities/session_status.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/domain/repositories/bot_session_repository.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_connect_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements BotSessionRepository {}

final _link = ConnectLink(
  url: 'https://api.ataulfo.app/connect?token=tok',
  expiresAt: DateTime.utc(2026, 5, 29, 12, 30, 0),
);

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  test('estado inicial = BotConnectLoading', () {
    final bloc = BotConnectBloc(repo: repo, botId: 'b1');
    expect(bloc.state, const BotConnectLoading());
    bloc.close();
  });

  blocTest<BotConnectBloc, BotConnectState>(
    'Started SOLO emite el enlace; NO arranca la sesión (link async)',
    build: () {
      when(() => repo.issueConnectLink('b1')).thenAnswer((_) async => _link);
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    act: (bloc) => bloc.add(const BotConnectStarted()),
    expect: () => <BotConnectState>[BotConnectReady(_link)],
    verify: (_) {
      verify(() => repo.issueConnectLink('b1')).called(1);
      // Clave del fix: arrancar la sesión al emitir el enlace cerraría el QR
      // (~2 min) antes de que el tercero abra el enlace. Start es aparte.
      verifyNever(() => repo.startSession(any()));
    },
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'mint falla → [Failed]',
    build: () {
      when(
        () => repo.issueConnectLink('b1'),
      ).thenThrow(const BotsServerFailure());
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    act: (bloc) => bloc.add(const BotConnectStarted()),
    expect: () => const <BotConnectState>[
      BotConnectFailed(BotsServerFailure()),
    ],
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'PairingRequested arranca la sesión → [starting, active]',
    build: () {
      when(() => repo.startSession('b1')).thenAnswer((_) async {});
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => BotConnectReady(_link),
    act: (bloc) => bloc.add(const BotConnectPairingRequested()),
    expect: () => <BotConnectState>[
      BotConnectReady(_link, phase: PairingPhase.starting),
      BotConnectReady(_link, phase: PairingPhase.active),
    ],
    verify: (_) => verify(() => repo.startSession('b1')).called(1),
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'PairingRequested con fallo de start → [starting, failed] conservando el enlace',
    build: () {
      when(() => repo.startSession('b1')).thenThrow(const BotsServerFailure());
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => BotConnectReady(_link),
    act: (bloc) => bloc.add(const BotConnectPairingRequested()),
    expect: () => <BotConnectState>[
      BotConnectReady(_link, phase: PairingPhase.starting),
      BotConnectReady(_link, phase: PairingPhase.failed),
    ],
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'retry del mint desde Failed → [Loading, Ready]',
    build: () {
      when(() => repo.issueConnectLink('b1')).thenAnswer((_) async => _link);
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => const BotConnectFailed(BotsServerFailure()),
    act: (bloc) => bloc.add(const BotConnectStarted()),
    expect: () => <BotConnectState>[
      const BotConnectLoading(),
      BotConnectReady(_link),
    ],
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'StopRequested desde Ready(active) → stopSession invocado → Ready(idle)',
    build: () {
      when(() => repo.stopSession('b1')).thenAnswer((_) async {});
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => BotConnectReady(_link, phase: PairingPhase.active),
    act: (bloc) => bloc.add(const BotConnectStopRequested()),
    expect: () => <BotConnectState>[BotConnectReady(_link)],
    verify: (_) => verify(() => repo.stopSession('b1')).called(1),
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'StopRequested idempotente: aun si stopSession falla, vuelve a idle',
    build: () {
      when(() => repo.stopSession('b1')).thenThrow(const BotsServerFailure());
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => BotConnectReady(_link, phase: PairingPhase.active),
    act: (bloc) => bloc.add(const BotConnectStopRequested()),
    expect: () => <BotConnectState>[BotConnectReady(_link)],
    verify: (_) => verify(() => repo.stopSession('b1')).called(1),
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'StopRequested fuera de Ready se ignora (no llama stopSession)',
    build: () => BotConnectBloc(repo: repo, botId: 'b1'),
    act: (bloc) => bloc.add(const BotConnectStopRequested()),
    expect: () => const <BotConnectState>[],
    verify: (_) => verifyNever(() => repo.stopSession(any())),
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'WipeRequested desde Ready → wipeCredentials invocado → Ready(idle)',
    build: () {
      when(() => repo.wipeCredentials('b1')).thenAnswer((_) async {});
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => BotConnectReady(_link, phase: PairingPhase.active),
    act: (bloc) => bloc.add(const BotConnectWipeRequested()),
    expect: () => <BotConnectState>[BotConnectReady(_link)],
    verify: (_) => verify(() => repo.wipeCredentials('b1')).called(1),
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'WipeRequested idempotente: aun si falla, vuelve a idle',
    build: () {
      when(
        () => repo.wipeCredentials('b1'),
      ).thenThrow(const BotsServerFailure());
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => BotConnectReady(_link, phase: PairingPhase.active),
    act: (bloc) => bloc.add(const BotConnectWipeRequested()),
    expect: () => <BotConnectState>[BotConnectReady(_link)],
    verify: (_) => verify(() => repo.wipeCredentials('b1')).called(1),
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'WipeRequested fuera de Ready se ignora',
    build: () => BotConnectBloc(repo: repo, botId: 'b1'),
    act: (bloc) => bloc.add(const BotConnectWipeRequested()),
    expect: () => const <BotConnectState>[],
    verify: (_) => verifyNever(() => repo.wipeCredentials(any())),
  );

  group('poll de estado (S11)', () {
    blocTest<BotConnectBloc, BotConnectState>(
      'StatusPolled PAIRING → Ready con status PAIRING + qr',
      build: () {
        when(() => repo.getSessionState('b1')).thenAnswer(
          (_) async =>
              const SessionStatus(state: SessionState.pairing, qrCode: 'QR1'),
        );
        return BotConnectBloc(repo: repo, botId: 'b1');
      },
      seed: () => BotConnectReady(_link, phase: PairingPhase.active),
      act: (bloc) => bloc.add(const BotConnectStatusPolled()),
      expect: () => <BotConnectState>[
        BotConnectReady(
          _link,
          phase: PairingPhase.active,
          status: const SessionStatus(
            state: SessionState.pairing,
            qrCode: 'QR1',
          ),
        ),
      ],
      verify: (_) => verify(() => repo.getSessionState('b1')).called(1),
    );

    blocTest<BotConnectBloc, BotConnectState>(
      'StatusPolled PAIRING→DISCONNECTED → qrExpired',
      build: () {
        when(() => repo.getSessionState('b1')).thenAnswer(
          (_) async => const SessionStatus(state: SessionState.disconnected),
        );
        return BotConnectBloc(repo: repo, botId: 'b1');
      },
      seed: () => BotConnectReady(
        _link,
        phase: PairingPhase.active,
        status: const SessionStatus(state: SessionState.pairing, qrCode: 'QR1'),
      ),
      act: (bloc) => bloc.add(const BotConnectStatusPolled()),
      expect: () => <BotConnectState>[
        BotConnectReady(
          _link,
          phase: PairingPhase.active,
          status: const SessionStatus(state: SessionState.disconnected),
          qrExpired: true,
        ),
      ],
    );

    blocTest<BotConnectBloc, BotConnectState>(
      'StatusPolled CONNECTED → Ready status CONNECTED, sin expiración',
      build: () {
        when(() => repo.getSessionState('b1')).thenAnswer(
          (_) async => const SessionStatus(state: SessionState.connected),
        );
        return BotConnectBloc(repo: repo, botId: 'b1');
      },
      seed: () => BotConnectReady(_link, phase: PairingPhase.active),
      act: (bloc) => bloc.add(const BotConnectStatusPolled()),
      expect: () => <BotConnectState>[
        BotConnectReady(
          _link,
          phase: PairingPhase.active,
          status: const SessionStatus(state: SessionState.connected),
        ),
      ],
    );

    blocTest<BotConnectBloc, BotConnectState>(
      'StatusPolled fuera de Ready se ignora',
      build: () => BotConnectBloc(repo: repo, botId: 'b1'),
      act: (bloc) => bloc.add(const BotConnectStatusPolled()),
      expect: () => const <BotConnectState>[],
      verify: (_) => verifyNever(() => repo.getSessionState(any())),
    );

    test('el poll arranca tras Pairing y se DETIENE al llegar a CONNECTED', () {
      fakeAsync((async) {
        when(() => repo.issueConnectLink('b1')).thenAnswer((_) async => _link);
        when(() => repo.startSession('b1')).thenAnswer((_) async {});
        var calls = 0;
        when(() => repo.getSessionState('b1')).thenAnswer((_) async {
          calls++;
          // PAIRING en el primer tick, CONNECTED en el segundo → debe parar.
          return SessionStatus(
            state: calls >= 2 ? SessionState.connected : SessionState.pairing,
          );
        });

        final bloc = BotConnectBloc(repo: repo, botId: 'b1');
        bloc.add(const BotConnectStarted());
        async.flushMicrotasks();
        bloc.add(const BotConnectPairingRequested());
        async.flushMicrotasks();

        // Antes de cualquier tick no se ha sondeado.
        expect(calls, 0);

        async.elapse(const Duration(seconds: 2)); // tick 1 → PAIRING
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2)); // tick 2 → CONNECTED → para
        async.flushMicrotasks();
        expect(calls, 2);

        // Tras CONNECTED el timer está cancelado: no hay más polls.
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(calls, 2);

        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('el poll SIGUE activo en RECONNECTING (transitorio, no se estanca)', () {
      fakeAsync((async) {
        when(
          () => repo.issueConnectLink('b1'),
        ).thenAnswer((_) async => _link);
        when(() => repo.startSession('b1')).thenAnswer((_) async {});
        var calls = 0;
        when(() => repo.getSessionState('b1')).thenAnswer((_) async {
          calls++;
          return SessionStatus(
            state: switch (calls) {
              1 => SessionState.pairing,
              2 => SessionState.reconnecting,
              _ => SessionState.connected,
            },
          );
        });

        final bloc = BotConnectBloc(repo: repo, botId: 'b1');
        bloc.add(const BotConnectStarted());
        async.flushMicrotasks();
        bloc.add(const BotConnectPairingRequested());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2)); // PAIRING
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2)); // RECONNECTING → debe seguir
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2)); // CONNECTED → para
        async.flushMicrotasks();
        expect(calls, 3);
        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('stop durante un poll en vuelo NO produce un falso qrExpired', () {
      fakeAsync((async) {
        when(
          () => repo.issueConnectLink('b1'),
        ).thenAnswer((_) async => _link);
        when(() => repo.startSession('b1')).thenAnswer((_) async {});
        when(() => repo.stopSession('b1')).thenAnswer((_) async {});
        final inFlight = Completer<SessionStatus>();
        var calls = 0;
        when(() => repo.getSessionState('b1')).thenAnswer((_) {
          calls++;
          if (calls == 1) {
            return Future<SessionStatus>.value(
              const SessionStatus(state: SessionState.pairing, qrCode: 'Q'),
            );
          }
          return inFlight.future; // 2.º poll: queda en vuelo
        });

        final bloc = BotConnectBloc(repo: repo, botId: 'b1');
        final seen = <BotConnectState>[];
        final sub = bloc.stream.listen(seen.add);
        bloc.add(const BotConnectStarted());
        async.flushMicrotasks();
        bloc.add(const BotConnectPairingRequested());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2)); // poll 1 → PAIRING + qr
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2)); // poll 2 → en vuelo
        async.flushMicrotasks();

        // El operador cancela mientras el poll 2 sigue en vuelo.
        bloc.add(const BotConnectStopRequested());
        async.flushMicrotasks();
        // Ahora el poll 2 resuelve con DISCONNECTED — NO debe pintar "expiró".
        inFlight.complete(
          const SessionStatus(state: SessionState.disconnected),
        );
        async.flushMicrotasks();

        expect(bloc.state, BotConnectReady(_link)); // idle, sin qrExpired
        expect(
          seen.whereType<BotConnectReady>().any((s) => s.qrExpired),
          isFalse,
        );
        sub.cancel();
        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('close cancela el poll (no hay más polls tras cerrar)', () {
      fakeAsync((async) {
        when(() => repo.issueConnectLink('b1')).thenAnswer((_) async => _link);
        when(() => repo.startSession('b1')).thenAnswer((_) async {});
        var calls = 0;
        when(() => repo.getSessionState('b1')).thenAnswer((_) async {
          calls++;
          return const SessionStatus(state: SessionState.pairing);
        });

        final bloc = BotConnectBloc(repo: repo, botId: 'b1');
        bloc.add(const BotConnectStarted());
        async.flushMicrotasks();
        bloc.add(const BotConnectPairingRequested());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2)); // 1 poll (sigue PAIRING)
        async.flushMicrotasks();
        expect(calls, 1);

        bloc.close();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(calls, 1); // ningún poll tras close
      });
    });
  });
}
