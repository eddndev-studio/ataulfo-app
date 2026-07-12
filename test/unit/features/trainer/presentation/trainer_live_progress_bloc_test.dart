import 'dart:async';

import 'package:ataulfo/features/trainer/domain/entities/trainer_conversation.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_models.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_progress.dart';
import 'package:ataulfo/features/trainer/domain/failures/trainer_failure.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/trainer_chat_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements TrainerRepository {}

class _MockEvents extends Mock implements TrainerEvents {}

/// Stream cuyo `cancel()` NUNCA completa: reproduce el desmonte de un socket
/// SSE vivo que el servidor mantiene abierto. Entrega los eventos del inner;
/// solo el cancel cuelga. Si el bloc `await`ea ese cancel antes de cerrar el
/// turno, se queda en "Pensando…".
class _HangingCancelStream<T> extends Stream<T> {
  _HangingCancelStream(this._inner);

  final Stream<T> _inner;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _HangingSubscription<T>(
    _inner.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    ),
  );
}

class _HangingSubscription<T> implements StreamSubscription<T> {
  _HangingSubscription(this._inner);

  final StreamSubscription<T> _inner;

  @override
  Future<void> cancel() => Completer<void>().future; // nunca completa

  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);
  @override
  void onError(Function? handleError) => _inner.onError(handleError);
  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);
  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);
  @override
  void resume() => _inner.resume();
  @override
  bool get isPaused => _inner.isPaused;
  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture<E>(futureValue);
}

TrainerConversation _conv({String id = 'c1'}) => TrainerConversation(
  id: id,
  templateId: 't1',
  title: 'Entrenamiento',
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

TrainerMessage _msg(
  String id,
  String role,
  String content, {
  String conv = 'c1',
}) => TrainerMessage(
  id: id,
  conversationId: conv,
  role: role,
  content: content,
  createdAt: DateTime.utc(2026, 6, 10, 10),
);

TrainerProgressEvent _prog(
  String kind, {
  String tool = '',
  String conv = 'c1',
}) => TrainerProgressEvent(
  kind: kind,
  conversationId: conv,
  at: DateTime.utc(2026, 6, 10, 10),
  toolName: tool,
);

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  late _MockRepo repo;
  late _MockEvents events;

  setUp(() {
    repo = _MockRepo();
    events = _MockEvents();
    when(
      () => events.progress(any(), any()),
    ).thenAnswer((_) => const Stream<TrainerProgressEvent>.empty());
    when(
      () => repo.listModels(templateId: any(named: 'templateId')),
    ).thenAnswer(
      (_) async =>
          const TrainerModels(options: <TrainerModelOption>[], defaultId: ''),
    );
  });

  TrainerChatBloc build() =>
      TrainerChatBloc(repo: repo, templateId: 't1', events: events);

  TrainerChatLoaded loaded({
    bool sending = false,
    List<TrainerProgressEvent> liveEvents = const <TrainerProgressEvent>[],
  }) => TrainerChatLoaded(
    conversation: _conv(),
    messages: const <TrainerMessage>[],
    sending: sending,
    liveEvents: liveEvents,
  );

  void stubSendAndReload() {
    when(
      () => repo.sendMessage(
        templateId: any(named: 'templateId'),
        conversationId: any(named: 'conversationId'),
        content: any(named: 'content'),
        model: any(named: 'model'),
        attachments: any(named: 'attachments'),
      ),
    ).thenAnswer((_) async => _msg('m9', 'assistant', 'listo'));
    when(
      () => repo.listMessages(
        templateId: any(named: 'templateId'),
        conversationId: any(named: 'conversationId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => TrainerMessagesPage(
        messages: <TrainerMessage>[
          _msg('m9', 'assistant', 'listo'),
          _msg('m8', 'user', 'hola'),
        ],
        nextCursor: '',
      ),
    );
  }

  blocTest<TrainerChatBloc, TrainerChatState>(
    'MessageSent: abre con la traza viva vacía y el swap de la recarga la retira',
    build: build,
    seed: () => loaded(),
    setUp: stubSendAndReload,
    act: (b) => b.add(const TrainerChatMessageSent('hola')),
    expect: () => <dynamic>[
      isA<TrainerChatLoaded>()
          .having((s) => s.sending, 'sending', true)
          .having((s) => s.liveEvents, 'sin eventos aún', isEmpty)
          .having((s) => s.messages.last.content, 'optimista', 'hola'),
      // Cierre inmediato: sending=false con el assistant del POST ANEXADO
      // (si la recarga falla, la respuesta ya vive en el hilo).
      isA<TrainerChatLoaded>()
          .having((s) => s.sending, 'sending', false)
          .having((s) => s.messages.last.content, 'assistant anexado', 'listo'),
      // Recarga: aparece la respuesta del server y la viva queda descartada.
      isA<TrainerChatLoaded>()
          .having((s) => s.sending, 'sending', false)
          .having((s) => s.liveEvents, 'swap: viva descartada', isEmpty)
          .having(
            (s) => s.messages.any((m) => m.isAssistant),
            'assistant',
            true,
          ),
    ],
    verify: (_) {
      verify(() => events.progress('t1', 'c1')).called(1);
    },
  );

  blocTest<TrainerChatBloc, TrainerChatState>(
    'ProgressReceived acumula los eventos del SSE en la traza viva',
    build: build,
    seed: () => loaded(
      sending: true,
      liveEvents: <TrainerProgressEvent>[_prog('thinking')],
    ),
    act: (b) =>
        b.add(TrainerChatProgressReceived(_prog('tool', tool: 'inspect_flow'))),
    expect: () => <dynamic>[
      isA<TrainerChatLoaded>()
          .having((s) => s.liveEvents.length, 'acumulados', 2)
          .having(
            (s) => s.liveEvents.last.toolName,
            'último tool',
            'inspect_flow',
          ),
    ],
  );

  blocTest<TrainerChatBloc, TrainerChatState>(
    'ProgressReceived sin turno en vuelo se ignora (no repinta un hilo ocioso)',
    build: build,
    seed: () => loaded(sending: false),
    act: (b) => b.add(TrainerChatProgressReceived(_prog('thinking'))),
    expect: () => <dynamic>[],
  );

  blocTest<TrainerChatBloc, TrainerChatState>(
    'MessageSent: el cancel del SSE vivo cuelga — el turno IGUAL cierra '
    '(sending=false con la respuesta), no se queda en Pensando…',
    build: build,
    seed: () => loaded(),
    setUp: () {
      when(() => events.progress(any(), any())).thenAnswer(
        (_) => _HangingCancelStream<TrainerProgressEvent>(
          const Stream<TrainerProgressEvent>.empty(),
        ),
      );
      stubSendAndReload();
    },
    act: (b) => b.add(const TrainerChatMessageSent('hola')),
    expect: () => <dynamic>[
      isA<TrainerChatLoaded>().having((s) => s.sending, 'sending', true),
      // Cierre inmediato (sending=false) aunque el cancel del SSE cuelgue,
      // ya con el assistant del POST anexado.
      isA<TrainerChatLoaded>()
          .having((s) => s.sending, 'sending', false)
          .having((s) => s.messages.last.content, 'assistant anexado', 'listo'),
      // Recarga: la respuesta del server entra al hilo.
      isA<TrainerChatLoaded>()
          .having((s) => s.sending, 'sending', false)
          .having(
            (s) => s.messages.where((m) => m.content == 'listo').length,
            'assistant del POST visible',
            1,
          ),
    ],
  );

  // P1 de F3: el cierre del turno NO debe emitir desde el snapshot pre-turno.
  // Un cambio de modelo mid-turno (mientras el POST viaja) debe sobrevivir al
  // cierre, que relee el state en vez de pisarlo con `current`.
  late TrainerChatBloc midTurnBloc;
  blocTest<TrainerChatBloc, TrainerChatState>(
    'MessageSent: un cambio de modelo mid-turno NO se pierde al cerrar el turno',
    build: () {
      midTurnBloc = build();
      return midTurnBloc;
    },
    seed: () => loaded(),
    setUp: () {
      when(
        () => repo.sendMessage(
          templateId: any(named: 'templateId'),
          conversationId: any(named: 'conversationId'),
          content: any(named: 'content'),
          model: any(named: 'model'),
          attachments: any(named: 'attachments'),
        ),
      ).thenAnswer((_) async {
        // El operador cambia de modelo mientras el POST está en vuelo.
        midTurnBloc.add(const TrainerChatModelSelected('m2'));
        await Future<void>.delayed(Duration.zero);
        return _msg('m9', 'assistant', 'ok');
      });
      when(
        () => repo.listMessages(
          templateId: any(named: 'templateId'),
          conversationId: any(named: 'conversationId'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => TrainerMessagesPage(
          messages: <TrainerMessage>[
            _msg('m9', 'assistant', 'ok'),
            _msg('m8', 'user', 'x'),
          ],
          nextCursor: '',
        ),
      );
    },
    act: (b) => b.add(const TrainerChatMessageSent('x')),
    expect: () => <dynamic>[
      // optimista: sending, modelo aún el default.
      isA<TrainerChatLoaded>()
          .having((s) => s.sending, 'sending', true)
          .having((s) => s.selectedModelId, 'modelo', ''),
      // el cambio de modelo mid-turno.
      isA<TrainerChatLoaded>()
          .having((s) => s.sending, 'sending', true)
          .having((s) => s.selectedModelId, 'modelo', 'm2'),
      // cierre: el modelo elegido SOBREVIVE (releer state, no el snapshot).
      isA<TrainerChatLoaded>()
          .having((s) => s.sending, 'sending', false)
          .having((s) => s.selectedModelId, 'modelo preservado', 'm2'),
      // recarga best-effort: el modelo sigue preservado.
      isA<TrainerChatLoaded>()
          .having((s) => s.selectedModelId, 'modelo preservado', 'm2')
          .having((s) => s.messages.first.id, 'recarga ASC', 'm8'),
    ],
  );

  // La traza viva SOBREVIVE al cierre del POST: swap solo cuando la recarga
  // trae la verdad persistida; si la recarga falla, queda marcada parcial —
  // jamás se esfuma el proceso que el operador estaba viendo.
  group('traza viva post-cierre', () {
    void mockTurno({required bool reloadOk}) {
      when(() => events.progress('t1', 'c1')).thenAnswer(
        (_) => Stream<TrainerProgressEvent>.fromIterable(<TrainerProgressEvent>[
          _prog('tool', tool: 'edit_prompt'),
        ]),
      );
      when(
        () => repo.sendMessage(
          templateId: any(named: 'templateId'),
          conversationId: any(named: 'conversationId'),
          content: any(named: 'content'),
          model: any(named: 'model'),
          attachments: any(named: 'attachments'),
        ),
      ).thenAnswer((_) async {
        // Deja aterrizar el frame de progreso antes de cerrar el POST.
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _msg('m9', 'assistant', 'listo');
      });
      if (reloadOk) {
        when(
          () => repo.listMessages(
            templateId: any(named: 'templateId'),
            conversationId: any(named: 'conversationId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => TrainerMessagesPage(
            messages: <TrainerMessage>[
              _msg('m9', 'assistant', 'listo'),
              _msg('m8', 'user', 'hola'),
            ],
            nextCursor: '',
          ),
        );
      } else {
        when(
          () => repo.listMessages(
            templateId: any(named: 'templateId'),
            conversationId: any(named: 'conversationId'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const TrainerServerFailure());
      }
    }

    blocTest<TrainerChatBloc, TrainerChatState>(
      'recarga exitosa ⇒ swap: la persistida toma el relevo y la viva se va',
      build: build,
      seed: () => loaded(),
      setUp: () => mockTurno(reloadOk: true),
      act: (b) async {
        b.add(const TrainerChatMessageSent('hola'));
        await Future<void>.delayed(const Duration(milliseconds: 40));
      },
      expect: () => <dynamic>[
        isA<TrainerChatLoaded>().having((s) => s.sending, 'optimista', true),
        isA<TrainerChatLoaded>().having(
          (s) => s.liveEvents,
          'frame vivo',
          hasLength(1),
        ),
        isA<TrainerChatLoaded>()
            .having((s) => s.sending, 'cierre', false)
            .having((s) => s.liveEvents, 'viva aún en mano', hasLength(1)),
        isA<TrainerChatLoaded>()
            .having((s) => s.liveEvents, 'swap: viva descartada', isEmpty)
            .having((s) => s.livePartial, 'sin marca', false)
            .having((s) => s.messages.first.id, 'reload ASC', 'm8'),
      ],
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'recarga fallida ⇒ la viva se CONSERVA marcada parcial',
      build: build,
      seed: () => loaded(),
      setUp: () => mockTurno(reloadOk: false),
      act: (b) async {
        b.add(const TrainerChatMessageSent('hola'));
        await Future<void>.delayed(const Duration(milliseconds: 40));
      },
      expect: () => <dynamic>[
        isA<TrainerChatLoaded>().having((s) => s.sending, 'optimista', true),
        isA<TrainerChatLoaded>().having(
          (s) => s.liveEvents,
          'frame vivo',
          hasLength(1),
        ),
        isA<TrainerChatLoaded>()
            .having((s) => s.sending, 'cierre', false)
            .having((s) => s.liveEvents, 'viva conservada', hasLength(1))
            .having((s) => s.livePartial, 'aún sin marca', false)
            // El assistant del POST se anexa al cerrar: aunque la recarga
            // falle, la respuesta ya vive en el hilo.
            .having(
              (s) =>
                  s.messages.any((m) => m.id == 'm9' && m.content == 'listo'),
              'respuesta del POST en el hilo',
              true,
            ),
        isA<TrainerChatLoaded>()
            .having((s) => s.livePartial, 'marcada parcial', true)
            .having((s) => s.liveEvents, 'sigue en mano', hasLength(1))
            .having(
              (s) => s.messages.any((m) => m.id == 'm9'),
              'la respuesta sobrevive a la recarga fallida',
              true,
            ),
      ],
    );
  });

  blocTest<TrainerChatBloc, TrainerChatState>(
    'TurnCancelRequested ancla la traza viva al copy honesto (liveStopped) '
    'sin descartar sus eventos',
    build: build,
    seed: () => loaded(
      sending: true,
      liveEvents: <TrainerProgressEvent>[_prog('thinking')],
    ),
    setUp: () {
      when(() => repo.cancelSend()).thenAnswer((_) {});
    },
    act: (b) => b.add(const TrainerChatTurnCancelRequested()),
    expect: () => <dynamic>[
      isA<TrainerChatLoaded>()
          .having((s) => s.sending, 'cancelado', false)
          .having((s) => s.liveStopped, 'traza anclada', true)
          .having((s) => s.liveEvents, 'eventos conservados', hasLength(1)),
    ],
    verify: (_) {
      verify(() => repo.cancelSend()).called(1);
    },
  );

  blocTest<TrainerChatBloc, TrainerChatState>(
    'cambiar de hilo descarta la traza viva sobreviviente',
    build: build,
    seed: () => TrainerChatLoaded(
      conversation: _conv(),
      conversations: <TrainerConversation>[
        _conv(),
        _conv(id: 'c2'),
      ],
      messages: const <TrainerMessage>[],
      sending: false,
      liveEvents: <TrainerProgressEvent>[_prog('thinking')],
      liveStopped: true,
    ),
    setUp: () {
      when(
        () => repo.listMessages(
          templateId: 't1',
          conversationId: 'c2',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => const TrainerMessagesPage(
          messages: <TrainerMessage>[],
          nextCursor: '',
        ),
      );
    },
    act: (b) => b.add(const TrainerChatConversationSelected('c2')),
    expect: () => <dynamic>[
      isA<TrainerChatLoaded>()
          .having((s) => s.conversation.id, 'hilo', 'c2')
          .having((s) => s.liveEvents, 'viva descartada', isEmpty)
          .having((s) => s.liveStopped, 'ancla limpia', false),
    ],
  );
}
