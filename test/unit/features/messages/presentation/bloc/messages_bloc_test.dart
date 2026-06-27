import 'dart:async';

import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/domain/entities/outbox_entry.dart';
import 'package:ataulfo/features/messages/domain/entities/thread_live_event.dart';
import 'package:ataulfo/features/messages/domain/failures/messages_failure.dart';
import 'package:ataulfo/features/messages/domain/repositories/messages_repository.dart';
import 'package:ataulfo/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MessagesRepository {}

OutboxEntry _e(
  String token, {
  String content = 'hi',
  String type = 'text',
  String? mediaRef,
  bool isFailed = false,
  String? errorKind,
  int createdAtMs = 0,
}) => OutboxEntry(
  clientToken: token,
  type: type,
  content: content,
  mediaRef: mediaRef,
  isFailed: isFailed,
  errorKind: errorKind,
  createdAtMs: createdAtMs,
);

Message _m(
  String ext, {
  String chat = 'lid-1',
  int ts = 0,
  MessageStatus? status,
  MessageDirection dir = MessageDirection.inbound,
}) => Message(
  externalId: ext,
  chatLid: chat,
  senderLid: 's',
  kind: MessageKind.dm,
  direction: dir,
  type: 'text',
  content: 'hi',
  mediaRef: null,
  quotedId: null,
  timestampMs: ts,
  status: status,
);

/// Cede el loop para drenar microtasks (eventos del bloc + futures del repo).
Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  setUpAll(() {
    registerFallbackValue(_m('_'));
    registerFallbackValue(MessageStatus.sent);
  });

  late _MockRepo repo;
  late StreamController<List<Message>> watch;
  late StreamController<List<OutboxEntry>> pendingWatch;

  setUp(() {
    repo = _MockRepo();
    watch = StreamController<List<Message>>.broadcast();
    pendingWatch = StreamController<List<OutboxEntry>>.broadcast();
    when(() => repo.watchThread('b1', 'lid-1')).thenAnswer((_) => watch.stream);
    when(
      () => repo.watchPending('b1', 'lid-1'),
    ).thenAnswer((_) => pendingWatch.stream);
    when(() => repo.threadCursor('b1', 'lid-1')).thenAnswer((_) async => null);
    when(() => repo.refreshThread('b1', 'lid-1')).thenAnswer((_) async => null);
    when(
      () => repo.refreshThread('b1', 'lid-1', resetCursor: false),
    ).thenAnswer((_) async => null);
    when(() => repo.loadOlder('b1', 'lid-1')).thenAnswer((_) async => null);
    when(() => repo.applyLiveMessage(any(), any())).thenAnswer((_) async {});
    when(() => repo.applyStatus(any(), any(), any())).thenAnswer((_) async {});
    when(
      () => repo.live('b1'),
    ).thenAnswer((_) => const Stream<ThreadLiveEvent>.empty());
    when(() => repo.markRead('b1', 'lid-1')).thenAnswer((_) async {});
    when(
      () => repo.react(
        any(),
        any(),
        messageId: any(named: 'messageId'),
        emoji: any(named: 'emoji'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.send(
        any(),
        any(),
        clientToken: any(named: 'clientToken'),
        type: any(named: 'type'),
        content: any(named: 'content'),
        mediaRef: any(named: 'mediaRef'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.retrySend(any(), any(), any())).thenAnswer((_) async {});
    when(() => repo.discardSend(any(), any(), any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    await watch.close();
    await pendingWatch.close();
  });

  MessagesBloc build() => MessagesBloc(
    repo: repo,
    botId: 'b1',
    chatLid: 'lid-1',
    clientTokenFactory: () => 'tok-1',
  );

  test('estado inicial = MessagesInitial', () {
    expect(build().state, const MessagesInitial());
  });

  test(
    'load: Loading, refresca + observa el watch; el watch → Loaded',
    () async {
      final bloc = build();
      final states = <MessagesState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const MessagesLoadRequested());
      await tick();
      watch.add([_m('e1')]);
      await tick();

      expect(states.first, const MessagesLoading());
      final last = states.last as MessagesLoaded;
      expect(last.items, [_m('e1')]);
      verify(() => repo.refreshThread('b1', 'lid-1')).called(1);
      verify(() => repo.markRead('b1', 'lid-1')).called(1);
      verify(() => repo.live('b1')).called(1);

      await sub.cancel();
      await bloc.close();
    },
  );

  test(
    'offline con caché: refresh falla pero el watch sirve la caché',
    () async {
      final refresh = Completer<String?>();
      when(
        () => repo.refreshThread('b1', 'lid-1'),
      ).thenAnswer((_) => refresh.future);
      final bloc = build();
      final states = <MessagesState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const MessagesLoadRequested());
      await tick();
      watch.add([_m('e1')]); // caché local
      await tick();
      refresh.completeError(const MessagesNetworkFailure());
      await tick();

      expect(states.whereType<MessagesFailed>(), isEmpty);
      expect((states.last as MessagesLoaded).items, [_m('e1')]);
      await sub.cancel();
      await bloc.close();
    },
  );

  test('sin caché + refresh falla → Failed', () async {
    final refresh = Completer<String?>();
    when(
      () => repo.refreshThread('b1', 'lid-1'),
    ).thenAnswer((_) => refresh.future);
    final bloc = build();
    final states = <MessagesState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const MessagesLoadRequested());
    await tick();
    refresh.completeError(const MessagesNetworkFailure());
    await tick();

    expect(states.last, const MessagesFailed(MessagesNetworkFailure()));
    await sub.cancel();
    await bloc.close();
  });

  test('threadCursor siembra prevCursor (hasMore offline)', () async {
    when(
      () => repo.threadCursor('b1', 'lid-1'),
    ).thenAnswer((_) async => 'seed');
    final refresh = Completer<String?>();
    when(
      () => repo.refreshThread('b1', 'lid-1'),
    ).thenAnswer((_) => refresh.future);
    final bloc = build();
    final states = <MessagesState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const MessagesLoadRequested());
    await tick();
    watch.add([_m('e1')]);
    await tick();
    refresh.completeError(const MessagesNetworkFailure()); // offline
    await tick();

    expect((states.last as MessagesLoaded).prevCursor, 'seed');
    await sub.cancel();
    await bloc.close();
  });

  test(
    'paginación: Older llama loadOlder y el watch refleja el prepend',
    () async {
      when(
        () => repo.refreshThread('b1', 'lid-1'),
      ).thenAnswer((_) async => 'c1');
      when(() => repo.loadOlder('b1', 'lid-1')).thenAnswer((_) async => 'c2');
      final bloc = build();
      final states = <MessagesState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const MessagesLoadRequested());
      await tick();
      watch.add([_m('e2', ts: 2)]);
      await tick();
      expect((states.last as MessagesLoaded).prevCursor, 'c1');

      bloc.add(const MessagesOlderRequested());
      await tick();
      watch.add([_m('e1', ts: 1), _m('e2', ts: 2)]); // tramo viejo prepended
      await tick();

      final s = states.last as MessagesLoaded;
      expect(s.items, [_m('e1', ts: 1), _m('e2', ts: 2)]);
      expect(s.isLoadingOlder, isFalse);
      expect(s.prevCursor, 'c2');
      verify(() => repo.loadOlder('b1', 'lid-1')).called(1);
      await sub.cancel();
      await bloc.close();
    },
  );

  test('Older es no-op sin más histórico (prevCursor null)', () async {
    final bloc = build();
    bloc.add(const MessagesLoadRequested());
    await tick();
    watch.add([_m('e1')]);
    await tick();

    bloc.add(const MessagesOlderRequested());
    await tick();
    verifyNever(() => repo.loadOlder('b1', 'lid-1'));
    await bloc.close();
  });

  test(
    'mensaje en vivo del chat → applyLiveMessage; de otro chat → no',
    () async {
      final bloc = build();
      bloc.add(const MessagesLoadRequested());
      await tick();
      watch.add([_m('e1')]);
      await tick();

      bloc.add(MessagesLiveReceived(_m('e3', chat: 'lid-1')));
      await tick();
      verify(
        () => repo.applyLiveMessage('b1', _m('e3', chat: 'lid-1')),
      ).called(1);

      bloc.add(MessagesLiveReceived(_m('e4', chat: 'otro')));
      await tick();
      verifyNever(() => repo.applyLiveMessage('b1', _m('e4', chat: 'otro')));
      await bloc.close();
    },
  );

  test('receipt en vivo → applyStatus(externalId, status)', () async {
    final bloc = build();
    bloc.add(const MessagesLoadRequested());
    await tick();
    watch.add([
      _m('e1', dir: MessageDirection.outbound, status: MessageStatus.sent),
    ]);
    await tick();

    bloc.add(
      const MessagesStatusReceived(
        externalId: 'e1',
        status: MessageStatus.read,
      ),
    );
    await tick();
    verify(() => repo.applyStatus('b1', 'e1', MessageStatus.read)).called(1);
    await bloc.close();
  });

  test('reconnect → refreshThread(resetCursor: false)', () async {
    final bloc = build();
    bloc.add(const MessagesLoadRequested());
    await tick();
    watch.add([_m('e1')]);
    await tick();

    bloc.add(const MessagesReconnected());
    await tick();
    verify(
      () => repo.refreshThread('b1', 'lid-1', resetCursor: false),
    ).called(1);
    await bloc.close();
  });

  test(
    'envío: encola en el outbox (repo.send) y la burbuja la trae watchPending; '
    'al reconciliar (mensaje real + fila borrada) se limpia',
    () async {
      final bloc = build();
      final states = <MessagesState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const MessagesLoadRequested());
      await tick();
      watch.add(<Message>[]);
      await tick();

      bloc.add(const MessagesSendRequested(type: 'text', content: 'hola'));
      await tick();
      verify(
        () => repo.send(
          'b1',
          'lid-1',
          clientToken: 'tok-1',
          type: 'text',
          content: 'hola',
          mediaRef: null,
        ),
      ).called(1);

      // La burbuja es DURABLE: la trae el watch del outbox, no la memoria.
      pendingWatch.add([_e('tok-1', content: 'hola')]);
      await tick();
      final painting = states.last as MessagesLoaded;
      expect(painting.pending, hasLength(1));
      expect(painting.pending.first.clientToken, 'tok-1');

      // El coordinador reconcilia: el mensaje real aparece y la fila se borra.
      watch.add([_m('e9', dir: MessageDirection.outbound)]);
      pendingWatch.add(const <OutboxEntry>[]);
      await tick();
      final settled = states.last as MessagesLoaded;
      expect(settled.pending, isEmpty);
      expect(settled.items, [_m('e9', dir: MessageDirection.outbound)]);
      await sub.cancel();
      await bloc.close();
    },
  );

  test(
    'fila terminal del outbox → burbuja fallida con su MessagesFailure',
    () async {
      final bloc = build();
      final states = <MessagesState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const MessagesLoadRequested());
      await tick();
      watch.add(<Message>[]);
      await tick();
      pendingWatch.add([_e('tok-1', isFailed: true, errorKind: 'forbidden')]);
      await tick();

      final s = states.last as MessagesLoaded;
      expect(s.pending, hasLength(1));
      expect(s.pending.first.isFailed, isTrue);
      expect(s.pending.first.failure, isA<MessagesForbiddenFailure>());
      await sub.cancel();
      await bloc.close();
    },
  );

  test(
    'una fila pending/sending del outbox NO es fallida (se pinta "enviando")',
    () async {
      final bloc = build();
      final states = <MessagesState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const MessagesLoadRequested());
      await tick();
      watch.add(<Message>[]);
      await tick();
      // Reintentable (sigue pending con errorKind) ⇒ se sigue intentando, no falla.
      pendingWatch.add([_e('tok-1', errorKind: 'network')]);
      await tick();

      expect((states.last as MessagesLoaded).pending.first.isFailed, isFalse);
      await sub.cancel();
      await bloc.close();
    },
  );

  test('reintentar → repo.retrySend(clientToken)', () async {
    final bloc = build();
    bloc.add(const MessagesLoadRequested());
    await tick();
    watch.add(<Message>[]);
    await tick();

    bloc.add(const MessagesSendRetryRequested('tok-1'));
    await tick();
    verify(() => repo.retrySend('b1', 'lid-1', 'tok-1')).called(1);
    await bloc.close();
  });

  test('descartar → repo.discardSend(clientToken)', () async {
    final bloc = build();
    bloc.add(const MessagesLoadRequested());
    await tick();
    watch.add(<Message>[]);
    await tick();

    bloc.add(const MessagesSendDiscarded('tok-1'));
    await tick();
    verify(() => repo.discardSend('b1', 'lid-1', 'tok-1')).called(1);
    await bloc.close();
  });

  test(
    'envío en la ventana de caché (refresh en vuelo) NO se descarta',
    () async {
      final refresh = Completer<String?>();
      when(
        () => repo.refreshThread('b1', 'lid-1'),
      ).thenAnswer((_) => refresh.future);
      final bloc = build();

      bloc.add(const MessagesLoadRequested());
      await tick();
      watch.add([_m('e1')]); // caché mostrada → _started; refresh AÚN en vuelo
      await tick();
      bloc.add(const MessagesSendRequested(type: 'text', content: 'hola'));
      await tick();

      verify(
        () => repo.send(
          'b1',
          'lid-1',
          clientToken: 'tok-1',
          type: 'text',
          content: 'hola',
          mediaRef: null,
        ),
      ).called(1);
      refresh.complete(null);
      await tick();
      await bloc.close();
    },
  );

  test(
    'dedupe del eco: si el mensaje real ya apareció, la burbuja se suprime',
    () async {
      final bloc = build();
      final states = <MessagesState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const MessagesLoadRequested());
      await tick();
      // El eco SSE ya escribió el mensaje real (OUTBOUND, mismo content/type,
      // ts >= createdAt) ANTES de que el coordinador borre la fila del outbox.
      watch.add([_m('e9', dir: MessageDirection.outbound, ts: 100)]);
      await tick();
      pendingWatch.add([_e('tok-1', content: 'hi', createdAtMs: 50)]);
      await tick();

      final s = states.last as MessagesLoaded;
      expect(
        s.pending,
        isEmpty,
        reason: 'la burbuja se suprime: hay mensaje real',
      );
      expect(s.items, hasLength(1));
      await sub.cancel();
      await bloc.close();
    },
  );

  test(
    'dos envíos idénticos sin mensaje real → DOS burbujas (no se colapsan)',
    () async {
      final bloc = build();
      final states = <MessagesState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const MessagesLoadRequested());
      await tick();
      watch.add(<Message>[]);
      await tick();
      pendingWatch.add([
        _e('t1', content: 'hola', createdAtMs: 1),
        _e('t2', content: 'hola', createdAtMs: 2),
      ]);
      await tick();

      final s = states.last as MessagesLoaded;
      expect(s.pending.map((p) => p.clientToken), ['t1', 't2']);
      await sub.cancel();
      await bloc.close();
    },
  );

  test(
    'durable: una entrada del outbox al cargar pinta la burbuja aun sin mensajes',
    () async {
      final bloc = build();
      final states = <MessagesState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const MessagesLoadRequested());
      await tick();
      // El outbox ya tiene un envío (sesión previa) y el hilo está vacío.
      pendingWatch.add([_e('tok-1', content: 'persistido')]);
      await tick();
      watch.add(<Message>[]); // el watch de mensajes emite vacío
      await tick();

      final s = states.last as MessagesLoaded;
      expect(s.pending, hasLength(1));
      expect(s.pending.first.content, 'persistido');
      await sub.cancel();
      await bloc.close();
    },
  );

  test(
    'reaccionar: fallo señaliza por reactFailures sin tocar el hilo',
    () async {
      when(
        () => repo.react('b1', 'lid-1', messageId: 'e1', emoji: '👍'),
      ).thenThrow(const MessagesNetworkFailure());
      final bloc = build();
      final fails = <void>[];
      final fsub = bloc.reactFailures.listen(fails.add);

      bloc.add(const MessagesLoadRequested());
      await tick();
      watch.add([_m('e1')]);
      await tick();
      bloc.add(const MessagesReactRequested(messageId: 'e1', emoji: '👍'));
      await tick();

      expect(fails, hasLength(1));
      await fsub.cancel();
      await bloc.close();
    },
  );

  test(
    'un error del watch de mensajes NO esconde una burbuja durable',
    () async {
      final bloc = build();
      final states = <MessagesState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const MessagesLoadRequested());
      await tick();
      pendingWatch.add([_e('tok-1', content: 'persistido')]); // burbuja durable
      await tick();
      watch.addError(const MessagesNetworkFailure());
      await tick();

      expect(states.whereType<MessagesFailed>(), isEmpty);
      expect((states.last as MessagesLoaded).pending, hasLength(1));
      await sub.cancel();
      await bloc.close();
    },
  );

  test('Failed sin caché se RECUPERA cuando llega un envío durable', () async {
    final refresh = Completer<String?>();
    when(
      () => repo.refreshThread('b1', 'lid-1'),
    ).thenAnswer((_) => refresh.future);
    final bloc = build();
    final states = <MessagesState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const MessagesLoadRequested());
    await tick();
    refresh.completeError(
      const MessagesNetworkFailure(),
    ); // sin caché ni pending
    await tick();
    expect(states.last, isA<MessagesFailed>());

    // Llega un envío encolado (sesión previa) → recupera a Loaded con la burbuja.
    pendingWatch.add([_e('tok-1', content: 'persistido')]);
    await tick();
    expect((states.last as MessagesLoaded).pending, hasLength(1));
    await sub.cancel();
    await bloc.close();
  });

  test('un error del watch del outbox NO derriba el hilo', () async {
    final bloc = build();
    final states = <MessagesState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const MessagesLoadRequested());
    await tick();
    watch.add([_m('e1')]);
    await tick();
    pendingWatch.addError(const MessagesNetworkFailure());
    await tick();

    expect(states.whereType<MessagesFailed>(), isEmpty);
    expect(states.last, isA<MessagesLoaded>());
    await sub.cancel();
    await bloc.close();
  });

  test(
    'dedupe 1:1: un mensaje real suprime SÓLO una de dos burbujas idénticas',
    () async {
      final bloc = build();
      final states = <MessagesState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const MessagesLoadRequested());
      await tick();
      watch.add([
        _m('e9', dir: MessageDirection.outbound, ts: 100),
      ]); // content 'hi'
      await tick();
      pendingWatch.add([
        _e('t1', content: 'hi', createdAtMs: 1),
        _e('t2', content: 'hi', createdAtMs: 2),
      ]);
      await tick();

      // El único mensaje real consume sólo t1; t2 sigue visible.
      expect(
        (states.last as MessagesLoaded).pending.map((p) => p.clientToken),
        ['t2'],
      );
      await sub.cancel();
      await bloc.close();
    },
  );

  test(
    'dedupe: un mensaje real MÁS VIEJO que el envío no lo suprime',
    () async {
      final bloc = build();
      final states = <MessagesState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const MessagesLoadRequested());
      await tick();
      watch.add([_m('e9', dir: MessageDirection.outbound, ts: 10)]);
      await tick();
      pendingWatch.add([
        _e('t1', content: 'hi', createdAtMs: 50),
      ]); // creado DESPUÉS
      await tick();

      expect(
        (states.last as MessagesLoaded).pending.map((p) => p.clientToken),
        ['t1'],
      );
      await sub.cancel();
      await bloc.close();
    },
  );
}
