import 'dart:async';

import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/domain/entities/message_page.dart';
import 'package:ataulfo/features/messages/domain/entities/thread_live_event.dart';
import 'package:ataulfo/features/messages/domain/failures/messages_failure.dart';
import 'package:ataulfo/features/messages/domain/repositories/messages_repository.dart';
import 'package:ataulfo/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MessagesRepository {}

Message msg(String ext, int ts) => Message(
  externalId: ext,
  chatLid: 'lid-1',
  senderLid: 'a',
  kind: MessageKind.dm,
  direction: MessageDirection.inbound,
  type: 'text',
  content: 'c',
  mediaRef: null,
  quotedId: null,
  timestampMs: ts,
  status: null,
);

/// Una auto-respuesta del bot (OUTBOUND) del chat abierto.
Message outbound(String ext, int ts) => Message(
  externalId: ext,
  chatLid: 'lid-1',
  senderLid: 'bot',
  kind: MessageKind.dm,
  direction: MessageDirection.outbound,
  type: 'text',
  content: 'respuesta',
  mediaRef: null,
  quotedId: null,
  timestampMs: ts,
  status: null,
);

/// Un mensaje de OTRA conversación del mismo bot (debe filtrarse del hilo).
Message otherChat(String ext, int ts) => Message(
  externalId: ext,
  chatLid: 'lid-2',
  senderLid: 'x',
  kind: MessageKind.dm,
  direction: MessageDirection.inbound,
  type: 'text',
  content: 'otro',
  mediaRef: null,
  quotedId: null,
  timestampMs: ts,
  status: null,
);

void main() {
  late _MockRepo repo;
  late StreamController<ThreadLiveEvent> liveController;

  setUp(() {
    repo = _MockRepo();
    // Broadcast: su `close()` completa aunque nadie lo escuche (un
    // single-subscription controller sin listener cuelga el `close`, y eso
    // colgaría el tearDown de cada test). El test de cableado adjunta su
    // listener (vía el bloc) antes de emitir, así que broadcast le sirve igual.
    liveController = StreamController<ThreadLiveEvent>.broadcast();
    // Por defecto el stream en vivo no emite: los tests de carga sólo ejercen
    // HTTP. Los tests de realtime sobreescriben este stub.
    when(
      () => repo.live(any()),
    ).thenAnswer((_) => const Stream<ThreadLiveEvent>.empty());
  });

  tearDown(() => liveController.close());

  MessagesBloc build() =>
      MessagesBloc(repo: repo, botId: 'b1', chatLid: 'lid-1');

  group('Load (cola)', () {
    blocTest<MessagesBloc, MessagesState>(
      'éxito → [Loading, Loaded] con prevCursor',
      build: () {
        when(
          () => repo.thread(
            'b1',
            'lid-1',
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => MessagePage(
            messages: <Message>[msg('m4', 400), msg('m5', 500)],
            prevCursor: '300:m3',
          ),
        );
        return build();
      },
      act: (b) => b.add(const MessagesLoadRequested()),
      expect: () => <MessagesState>[
        const MessagesLoading(),
        MessagesLoaded(
          items: <Message>[msg('m4', 400), msg('m5', 500)],
          prevCursor: '300:m3',
          isLoadingOlder: false,
        ),
      ],
    );

    blocTest<MessagesBloc, MessagesState>(
      'failure → [Loading, Failed]',
      build: () {
        when(
          () => repo.thread(
            'b1',
            'lid-1',
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const MessagesServerFailure());
        return build();
      },
      act: (b) => b.add(const MessagesLoadRequested()),
      expect: () => <MessagesState>[
        const MessagesLoading(),
        const MessagesFailed(MessagesServerFailure()),
      ],
    );
  });

  group('LoadOlder', () {
    blocTest<MessagesBloc, MessagesState>(
      'prepende el tramo más viejo (ASC) + actualiza prevCursor',
      build: () {
        when(
          () => repo.thread(
            'b1',
            'lid-1',
            cursor: '300:m3',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => MessagePage(
            messages: <Message>[msg('m2', 200), msg('m3', 300)],
            prevCursor: null,
          ),
        );
        return build();
      },
      seed: () => MessagesLoaded(
        items: <Message>[msg('m4', 400), msg('m5', 500)],
        prevCursor: '300:m3',
        isLoadingOlder: false,
      ),
      act: (b) => b.add(const MessagesOlderRequested()),
      expect: () => <MessagesState>[
        MessagesLoaded(
          items: <Message>[msg('m4', 400), msg('m5', 500)],
          prevCursor: '300:m3',
          isLoadingOlder: true,
        ),
        MessagesLoaded(
          items: <Message>[
            msg('m2', 200),
            msg('m3', 300),
            msg('m4', 400),
            msg('m5', 500),
          ],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      ],
    );

    blocTest<MessagesBloc, MessagesState>(
      'sin prevCursor (inicio del hilo) → no-op',
      build: build,
      seed: () => MessagesLoaded(
        items: <Message>[msg('m1', 100)],
        prevCursor: null,
        isLoadingOlder: false,
      ),
      act: (b) => b.add(const MessagesOlderRequested()),
      expect: () => const <MessagesState>[],
    );

    blocTest<MessagesBloc, MessagesState>(
      'falla el tramo viejo → revierte isLoadingOlder y conserva el hilo',
      build: () {
        when(
          () => repo.thread(
            'b1',
            'lid-1',
            cursor: '300:m3',
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const MessagesNetworkFailure());
        return build();
      },
      seed: () => MessagesLoaded(
        items: <Message>[msg('m4', 400)],
        prevCursor: '300:m3',
        isLoadingOlder: false,
      ),
      act: (b) => b.add(const MessagesOlderRequested()),
      expect: () => <MessagesState>[
        MessagesLoaded(
          items: <Message>[msg('m4', 400)],
          prevCursor: '300:m3',
          isLoadingOlder: true,
        ),
        MessagesLoaded(
          items: <Message>[msg('m4', 400)],
          prevCursor: '300:m3',
          isLoadingOlder: false,
        ),
      ],
    );
  });

  group('Realtime (live)', () {
    // Lógica de _onLive a nivel de handler (sembrando un hilo cargado):
    // determinista, sin depender del timing de la suscripción.

    blocTest<MessagesBloc, MessagesState>(
      'agrega una auto-respuesta nueva del chat al final (ASC)',
      build: build,
      seed: () => MessagesLoaded(
        items: <Message>[msg('m1', 100)],
        prevCursor: null,
        isLoadingOlder: false,
      ),
      act: (b) => b.add(MessagesLiveReceived(outbound('w2', 200))),
      expect: () => <MessagesState>[
        MessagesLoaded(
          items: <Message>[msg('m1', 100), outbound('w2', 200)],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      ],
    );

    blocTest<MessagesBloc, MessagesState>(
      'dedup por externalId: un mensaje ya presente se ignora',
      build: build,
      seed: () => MessagesLoaded(
        items: <Message>[msg('m1', 100)],
        prevCursor: null,
        isLoadingOlder: false,
      ),
      // Mismo externalId que ya está en el hilo (llegó por HTTP o repetido).
      act: (b) => b.add(MessagesLiveReceived(msg('m1', 100))),
      expect: () => const <MessagesState>[],
    );

    blocTest<MessagesBloc, MessagesState>(
      'un mensaje de otra conversación del mismo bot se ignora',
      build: build,
      seed: () => MessagesLoaded(
        items: <Message>[msg('m1', 100)],
        prevCursor: null,
        isLoadingOlder: false,
      ),
      act: (b) => b.add(MessagesLiveReceived(otherChat('z9', 200))),
      expect: () => const <MessagesState>[],
    );

    blocTest<MessagesBloc, MessagesState>(
      'sin hilo cargado (Initial) un evento en vivo se ignora',
      build: build,
      act: (b) => b.add(MessagesLiveReceived(outbound('w2', 200))),
      expect: () => const <MessagesState>[],
    );

    // Cableado extremo a extremo: tras cargar la cola, un mensaje emitido por
    // el stream `repo.live` aparece en el hilo.
    blocTest<MessagesBloc, MessagesState>(
      'tras cargar la cola, un mensaje del stream aparece en el hilo',
      build: () {
        when(
          () => repo.thread(
            'b1',
            'lid-1',
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => MessagePage(
            messages: <Message>[msg('m1', 100)],
            prevCursor: null,
          ),
        );
        when(() => repo.live('b1')).thenAnswer((_) => liveController.stream);
        return build();
      },
      act: (b) async {
        b.add(const MessagesLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        liveController.add(LiveMessage(outbound('w2', 200)));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      expect: () => <MessagesState>[
        const MessagesLoading(),
        MessagesLoaded(
          items: <Message>[msg('m1', 100)],
          prevCursor: null,
          isLoadingOlder: false,
        ),
        MessagesLoaded(
          items: <Message>[msg('m1', 100), outbound('w2', 200)],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      ],
    );

    // Refetch-on-reconnect: al reconectar el stream, el bloc reconcilia contra
    // HTTP y funde el mensaje que se perdió durante el corte —ordenado por
    // timestamp, sin duplicar lo ya pintado.
    blocTest<MessagesBloc, MessagesState>(
      'al reconectar, refetcha la cola y funde el mensaje perdido en el corte',
      build: () {
        var call = 0;
        when(
          () => repo.thread(
            'b1',
            'lid-1',
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async {
          call++;
          // 1ª carga: sólo m1. Refetch tras reconectar: m1 + el m2 del hueco.
          return call == 1
              ? MessagePage(
                  messages: <Message>[msg('m1', 100)],
                  prevCursor: 'cur',
                )
              : MessagePage(
                  messages: <Message>[msg('m1', 100), msg('m2', 150)],
                  prevCursor: 'cur',
                );
        });
        when(() => repo.live('b1')).thenAnswer((_) => liveController.stream);
        return build();
      },
      act: (b) async {
        b.add(const MessagesLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        liveController.add(const LiveReconnected());
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      expect: () => <MessagesState>[
        const MessagesLoading(),
        MessagesLoaded(
          items: <Message>[msg('m1', 100)],
          prevCursor: 'cur',
          isLoadingOlder: false,
        ),
        // El refetch funde m2 (perdido en el corte) conservando prevCursor.
        MessagesLoaded(
          items: <Message>[msg('m1', 100), msg('m2', 150)],
          prevCursor: 'cur',
          isLoadingOlder: false,
        ),
      ],
    );

    // El refetch tras reconectar también recupera AVANCES de estado perdidos en
    // el corte: READ es terminal (no llega otro receipt), así que sin esto el
    // tick se quedaría stale hasta un pull-to-refresh manual. El conteo de items
    // NO cambia (mismo mensaje, otro status) ⇒ exige re-emitir por cambio real,
    // no por diferencia de longitud.
    blocTest<MessagesBloc, MessagesState>(
      'al reconectar, avanza el status del OUTBOUND desde la verdad HTTP',
      build: () {
        var call = 0;
        when(
          () => repo.thread(
            'b1',
            'lid-1',
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async {
          call++;
          // 1ª carga: w2 en SENT (los receipts del corte no llegaron en vivo).
          // Refetch: w2 ya en READ (la verdad HTTP avanzó durante el corte).
          return call == 1
              ? MessagePage(
                  messages: <Message>[
                    outbound('w2', 200).withStatus(MessageStatus.sent),
                  ],
                  prevCursor: 'cur',
                )
              : MessagePage(
                  messages: <Message>[
                    outbound('w2', 200).withStatus(MessageStatus.read),
                  ],
                  prevCursor: 'cur',
                );
        });
        when(() => repo.live('b1')).thenAnswer((_) => liveController.stream);
        return build();
      },
      act: (b) async {
        b.add(const MessagesLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        liveController.add(const LiveReconnected());
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      expect: () => <MessagesState>[
        const MessagesLoading(),
        MessagesLoaded(
          items: <Message>[outbound('w2', 200).withStatus(MessageStatus.sent)],
          prevCursor: 'cur',
          isLoadingOlder: false,
        ),
        MessagesLoaded(
          items: <Message>[outbound('w2', 200).withStatus(MessageStatus.read)],
          prevCursor: 'cur',
          isLoadingOlder: false,
        ),
      ],
    );
  });

  group('Realtime status (receipts)', () {
    blocTest<MessagesBloc, MessagesState>(
      'un OUTBOUND sin estado recibe su primer receipt (→ DELIVERED)',
      build: build,
      seed: () => MessagesLoaded(
        items: <Message>[msg('m1', 100), outbound('w2', 200)],
        prevCursor: null,
        isLoadingOlder: false,
      ),
      act: (b) => b.add(
        const MessagesStatusReceived(
          externalId: 'w2',
          status: MessageStatus.delivered,
        ),
      ),
      expect: () => <MessagesState>[
        MessagesLoaded(
          items: <Message>[
            msg('m1', 100),
            outbound('w2', 200).withStatus(MessageStatus.delivered),
          ],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      ],
    );

    blocTest<MessagesBloc, MessagesState>(
      'un receipt para un externalId ausente del hilo se ignora',
      build: build,
      seed: () => MessagesLoaded(
        items: <Message>[msg('m1', 100)],
        prevCursor: null,
        isLoadingOlder: false,
      ),
      act: (b) => b.add(
        const MessagesStatusReceived(
          externalId: 'zzz',
          status: MessageStatus.read,
        ),
      ),
      expect: () => const <MessagesState>[],
    );

    blocTest<MessagesBloc, MessagesState>(
      'un receipt que retrocede el estado (READ→DELIVERED) se ignora',
      build: build,
      seed: () => MessagesLoaded(
        items: <Message>[outbound('w2', 200).withStatus(MessageStatus.read)],
        prevCursor: null,
        isLoadingOlder: false,
      ),
      act: (b) => b.add(
        const MessagesStatusReceived(
          externalId: 'w2',
          status: MessageStatus.delivered,
        ),
      ),
      expect: () => const <MessagesState>[],
    );

    blocTest<MessagesBloc, MessagesState>(
      'sin hilo cargado (Initial) un receipt se ignora',
      build: build,
      act: (b) => b.add(
        const MessagesStatusReceived(
          externalId: 'w2',
          status: MessageStatus.read,
        ),
      ),
      expect: () => const <MessagesState>[],
    );

    // Cableado: un LiveStatus del stream `repo.live` repinta la burbuja.
    blocTest<MessagesBloc, MessagesState>(
      'tras cargar la cola, un LiveStatus del stream avanza el OUTBOUND',
      build: () {
        when(
          () => repo.thread(
            'b1',
            'lid-1',
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => MessagePage(
            messages: <Message>[
              outbound('w2', 200).withStatus(MessageStatus.sent),
            ],
            prevCursor: null,
          ),
        );
        when(() => repo.live('b1')).thenAnswer((_) => liveController.stream);
        return build();
      },
      act: (b) async {
        b.add(const MessagesLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        liveController.add(
          const LiveStatus(externalId: 'w2', status: MessageStatus.read),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      expect: () => <MessagesState>[
        const MessagesLoading(),
        MessagesLoaded(
          items: <Message>[outbound('w2', 200).withStatus(MessageStatus.sent)],
          prevCursor: null,
          isLoadingOlder: false,
        ),
        MessagesLoaded(
          items: <Message>[outbound('w2', 200).withStatus(MessageStatus.read)],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      ],
    );
  });
}
