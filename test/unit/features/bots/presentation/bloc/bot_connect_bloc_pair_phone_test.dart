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

const _pairing = SessionStatus(state: SessionState.pairing, qrCode: 'QR1');

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  blocTest<BotConnectBloc, BotConnectState>(
    'pedida feliz: requesting → código pintado',
    build: () {
      when(
        () => repo.pairPhone('b1', '5215512345678'),
      ).thenAnswer((_) async => 'WZYX-K9PT');
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () =>
        BotConnectReady(_link, phase: PairingPhase.active, status: _pairing),
    act: (bloc) => bloc.add(const BotConnectPairCodeRequested('5215512345678')),
    expect: () => <BotConnectState>[
      BotConnectReady(
        _link,
        phase: PairingPhase.active,
        status: _pairing,
        pairRequesting: true,
      ),
      BotConnectReady(
        _link,
        phase: PairingPhase.active,
        status: _pairing,
        pairCode: 'WZYX-K9PT',
      ),
    ],
    verify: (_) =>
        verify(() => repo.pairPhone('b1', '5215512345678')).called(1),
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'guard: sin status del poll (fase active, QR aún no llega) se ignora',
    build: () => BotConnectBloc(repo: repo, botId: 'b1'),
    seed: () => BotConnectReady(_link, phase: PairingPhase.active),
    act: (bloc) => bloc.add(const BotConnectPairCodeRequested('5215512345678')),
    expect: () => const <BotConnectState>[],
    verify: (_) => verifyNever(() => repo.pairPhone(any(), any())),
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'guard: fuera de PAIRING (CONNECTED) se ignora',
    build: () => BotConnectBloc(repo: repo, botId: 'b1'),
    seed: () => BotConnectReady(
      _link,
      phase: PairingPhase.active,
      status: const SessionStatus(state: SessionState.connected),
    ),
    act: (bloc) => bloc.add(const BotConnectPairCodeRequested('5215512345678')),
    expect: () => const <BotConnectState>[],
    verify: (_) => verifyNever(() => repo.pairPhone(any(), any())),
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'guard: con una pedida en vuelo se ignora la re-entrada',
    build: () => BotConnectBloc(repo: repo, botId: 'b1'),
    seed: () => BotConnectReady(
      _link,
      phase: PairingPhase.active,
      status: _pairing,
      pairRequesting: true,
    ),
    act: (bloc) => bloc.add(const BotConnectPairCodeRequested('5215512345678')),
    expect: () => const <BotConnectState>[],
    verify: (_) => verifyNever(() => repo.pairPhone(any(), any())),
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'pedir otro código limpia el anterior ANTES del POST',
    build: () {
      when(
        () => repo.pairPhone('b1', '5215512345678'),
      ).thenAnswer((_) async => 'NEW2-NEW2');
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => BotConnectReady(
      _link,
      phase: PairingPhase.active,
      status: _pairing,
      pairCode: 'OLD1-OLD1',
    ),
    act: (bloc) => bloc.add(const BotConnectPairCodeRequested('5215512345678')),
    expect: () => <BotConnectState>[
      // Cada pedida mata la anterior en whatsmeow: el código viejo desaparece
      // en cuanto se dispara la nueva, no cuando llega la respuesta.
      BotConnectReady(
        _link,
        phase: PairingPhase.active,
        status: _pairing,
        pairRequesting: true,
      ),
      BotConnectReady(
        _link,
        phase: PairingPhase.active,
        status: _pairing,
        pairCode: 'NEW2-NEW2',
      ),
    ],
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'fallo deja pairFailure y el QR sigue vivo (sin fase failed global)',
    build: () {
      when(
        () => repo.pairPhone('b1', '5215512345678'),
      ).thenThrow(const BotsPhoneRejectedFailure());
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () =>
        BotConnectReady(_link, phase: PairingPhase.active, status: _pairing),
    act: (bloc) => bloc.add(const BotConnectPairCodeRequested('5215512345678')),
    expect: () => <BotConnectState>[
      BotConnectReady(
        _link,
        phase: PairingPhase.active,
        status: _pairing,
        pairRequesting: true,
      ),
      BotConnectReady(
        _link,
        phase: PairingPhase.active,
        status: _pairing,
        pairFailure: const BotsPhoneRejectedFailure(),
      ),
    ],
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'qrExpired limpia pairCode y pairFailure (el código muere con el QR)',
    build: () {
      when(() => repo.getSessionState('b1')).thenAnswer(
        (_) async => const SessionStatus(state: SessionState.disconnected),
      );
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => BotConnectReady(
      _link,
      phase: PairingPhase.active,
      status: _pairing,
      pairCode: 'WZYX-K9PT',
      pairFailure: const BotsServerFailure(),
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
    'el poll preserva código y fallo mientras la sesión sigue PAIRING',
    build: () {
      when(() => repo.getSessionState('b1')).thenAnswer(
        (_) async =>
            const SessionStatus(state: SessionState.pairing, qrCode: 'QR2'),
      );
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => BotConnectReady(
      _link,
      phase: PairingPhase.active,
      status: _pairing,
      pairCode: 'WZYX-K9PT',
    ),
    act: (bloc) => bloc.add(const BotConnectStatusPolled()),
    expect: () => <BotConnectState>[
      BotConnectReady(
        _link,
        phase: PairingPhase.active,
        status: const SessionStatus(state: SessionState.pairing, qrCode: 'QR2'),
        pairCode: 'WZYX-K9PT',
      ),
    ],
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'stop limpia el código (vuelve al Ready pelado)',
    build: () {
      when(() => repo.stopSession('b1')).thenAnswer((_) async {});
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => BotConnectReady(
      _link,
      phase: PairingPhase.active,
      status: _pairing,
      pairCode: 'WZYX-K9PT',
    ),
    act: (bloc) => bloc.add(const BotConnectStopRequested()),
    expect: () => <BotConnectState>[BotConnectReady(_link)],
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'rearranque (PairingRequested) limpia código y fallo',
    build: () {
      when(() => repo.startSession('b1')).thenAnswer((_) async {});
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => BotConnectReady(
      _link,
      qrExpired: true,
      pairCode: 'WZYX-K9PT',
      pairFailure: const BotsServerFailure(),
    ),
    act: (bloc) => bloc.add(const BotConnectPairingRequested()),
    expect: () => <BotConnectState>[
      BotConnectReady(_link, phase: PairingPhase.starting),
      BotConnectReady(_link, phase: PairingPhase.active),
    ],
  );

  test('stop con la pedida en vuelo descarta el código (gen bump)', () {
    fakeAsync((async) {
      when(() => repo.issueConnectLink('b1')).thenAnswer((_) async => _link);
      when(() => repo.startSession('b1')).thenAnswer((_) async {});
      when(() => repo.stopSession('b1')).thenAnswer((_) async {});
      when(() => repo.getSessionState('b1')).thenAnswer((_) async => _pairing);
      final inFlight = Completer<String>();
      when(
        () => repo.pairPhone('b1', '5215512345678'),
      ).thenAnswer((_) => inFlight.future);

      final bloc = BotConnectBloc(repo: repo, botId: 'b1');
      final seen = <BotConnectState>[];
      final sub = bloc.stream.listen(seen.add);
      bloc.add(const BotConnectStarted());
      async.flushMicrotasks();
      bloc.add(const BotConnectPairingRequested());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2)); // poll 1 → PAIRING + qr
      async.flushMicrotasks();
      bloc.add(const BotConnectPairCodeRequested('5215512345678'));
      async.flushMicrotasks();

      // El operador cancela mientras la pedida sigue en vuelo…
      bloc.add(const BotConnectStopRequested());
      async.flushMicrotasks();
      // …y la respuesta llega tarde: NO debe resucitar un código muerto.
      inFlight.complete('WZYX-K9PT');
      async.flushMicrotasks();

      expect(bloc.state, BotConnectReady(_link));
      expect(
        seen.whereType<BotConnectReady>().any((s) => s.pairCode != null),
        isFalse,
      );
      sub.cancel();
      bloc.close();
      async.flushMicrotasks();
    });
  });

  test(
    'un poll en vuelo NO pisa el código recién pintado (snapshot viejo)',
    () {
      fakeAsync((async) {
        when(() => repo.issueConnectLink('b1')).thenAnswer((_) async => _link);
        when(() => repo.startSession('b1')).thenAnswer((_) async {});
        // Tick 1 resuelve al instante (PAIRING); tick 2 queda EN VUELO para que
        // el 200 de pairPhone aterrice en medio de su await.
        var polls = 0;
        final getInFlight = Completer<SessionStatus>();
        when(() => repo.getSessionState('b1')).thenAnswer((_) {
          polls++;
          return polls == 1 ? Future.value(_pairing) : getInFlight.future;
        });
        final pairInFlight = Completer<String>();
        when(
          () => repo.pairPhone('b1', '5215512345678'),
        ).thenAnswer((_) => pairInFlight.future);

        final bloc = BotConnectBloc(repo: repo, botId: 'b1');
        bloc.add(const BotConnectStarted());
        async.flushMicrotasks();
        bloc.add(const BotConnectPairingRequested());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2)); // poll 1 → PAIRING
        async.flushMicrotasks();
        bloc.add(const BotConnectPairCodeRequested('5215512345678'));
        async.flushMicrotasks(); // requesting: true
        async.elapse(const Duration(seconds: 2)); // poll 2 arranca y se cuelga
        async.flushMicrotasks();
        pairInFlight.complete('WZYX-K9PT'); // el código se pinta…
        async.flushMicrotasks();
        getInFlight.complete(_pairing); // …y el poll tardío NO debe pisarlo
        async.flushMicrotasks();

        final st = bloc.state;
        st as BotConnectReady;
        expect(st.pairCode, 'WZYX-K9PT');
        expect(
          st.pairRequesting,
          isFalse,
        ); // spinner apagado: sin bloqueo eterno

        bloc.close();
        async.flushMicrotasks();
      });
    },
  );

  test('fallo tardío con la sesión ya fuera de PAIRING no pinta error', () {
    fakeAsync((async) {
      when(() => repo.issueConnectLink('b1')).thenAnswer((_) async => _link);
      when(() => repo.startSession('b1')).thenAnswer((_) async {});
      var polls = 0;
      when(() => repo.getSessionState('b1')).thenAnswer((_) async {
        polls++;
        return polls == 1
            ? _pairing
            : const SessionStatus(state: SessionState.connecting);
      });
      final inFlight = Completer<String>();
      when(
        () => repo.pairPhone('b1', '5215512345678'),
      ).thenAnswer((_) => inFlight.future);

      final bloc = BotConnectBloc(repo: repo, botId: 'b1');
      bloc.add(const BotConnectStarted());
      async.flushMicrotasks();
      bloc.add(const BotConnectPairingRequested());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2)); // poll 1 → PAIRING
      async.flushMicrotasks();
      bloc.add(const BotConnectPairCodeRequested('5215512345678'));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2)); // poll 2 → CONNECTING
      async.flushMicrotasks();
      inFlight.completeError(const BotsServerFailure()); // fallo tardío
      async.flushMicrotasks();

      final st = bloc.state;
      st as BotConnectReady;
      // La sección pair-phone ya no está visible (fuera de PAIRING): un error
      // fantasma reaparecería si la sesión rebota a PAIRING. Solo se apaga el
      // spinner.
      expect(st.pairFailure, isNull);
      expect(st.pairRequesting, isFalse);

      bloc.close();
      async.flushMicrotasks();
    });
  });

  test(
    'respuesta tardía con la sesión ya fuera de PAIRING no pinta código',
    () {
      fakeAsync((async) {
        when(() => repo.issueConnectLink('b1')).thenAnswer((_) async => _link);
        when(() => repo.startSession('b1')).thenAnswer((_) async {});
        var polls = 0;
        when(() => repo.getSessionState('b1')).thenAnswer((_) async {
          polls++;
          // Tick 1: PAIRING con QR. Tick 2+: CONNECTING (ya están vinculando
          // por otra vía) — transitorio, el poll sigue y la gen NO se bumpea.
          return polls == 1
              ? _pairing
              : const SessionStatus(state: SessionState.connecting);
        });
        final inFlight = Completer<String>();
        when(
          () => repo.pairPhone('b1', '5215512345678'),
        ).thenAnswer((_) => inFlight.future);

        final bloc = BotConnectBloc(repo: repo, botId: 'b1');
        bloc.add(const BotConnectStarted());
        async.flushMicrotasks();
        bloc.add(const BotConnectPairingRequested());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2)); // poll 1 → PAIRING
        async.flushMicrotasks();
        bloc.add(const BotConnectPairCodeRequested('5215512345678'));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2)); // poll 2 → CONNECTING
        async.flushMicrotasks();
        inFlight.complete('WZYX-K9PT'); // respuesta tardía
        async.flushMicrotasks();

        final st = bloc.state;
        st as BotConnectReady;
        expect(st.status?.state, SessionState.connecting);
        expect(st.pairCode, isNull); // el código quedaría muerto: no pintarlo
        expect(st.pairRequesting, isFalse); // pero el spinner sí se apaga

        bloc.close();
        async.flushMicrotasks();
      });
    },
  );
}
