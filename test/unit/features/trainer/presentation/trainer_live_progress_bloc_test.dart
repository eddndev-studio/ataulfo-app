import 'dart:async';

import 'package:ataulfo/features/trainer/domain/entities/trainer_conversation.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_models.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_progress.dart';
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

TrainerMessage _msg(String id, String role, String content, {String conv = 'c1'}) =>
    TrainerMessage(
      id: id,
      conversationId: conv,
      role: role,
      content: content,
      createdAt: DateTime.utc(2026, 6, 10, 10),
    );

TrainerProgressEvent _prog(String kind, {String tool = '', String conv = 'c1'}) =>
    TrainerProgressEvent(
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

  TrainerChatLoaded loaded({bool sending = false, String liveProgress = ''}) =>
      TrainerChatLoaded(
        conversation: _conv(),
        messages: const <TrainerMessage>[],
        sending: sending,
        liveProgress: liveProgress,
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
    'MessageSent: abre con Pensando… y limpia el indicador al cerrar el turno',
    build: build,
    seed: () => loaded(),
    setUp: stubSendAndReload,
    act: (b) => b.add(const TrainerChatMessageSent('hola')),
    expect: () => <dynamic>[
      isA<TrainerChatLoaded>()
          .having((s) => s.sending, 'sending', true)
          .having((s) => s.liveProgress, 'progress', 'Pensando…')
          .having((s) => s.messages.last.content, 'optimista', 'hola'),
      isA<TrainerChatLoaded>()
          .having((s) => s.sending, 'sending', false)
          .having((s) => s.liveProgress, 'progress', '')
          .having((s) => s.messages.any((m) => m.isAssistant), 'assistant', true),
    ],
    verify: (_) {
      verify(() => events.progress('t1', 'c1')).called(1);
    },
  );

  blocTest<TrainerChatBloc, TrainerChatState>(
    'ProgressReceived(tool): pinta "Usando {tool}…" mientras el turno viaja',
    build: build,
    seed: () => loaded(sending: true, liveProgress: 'Pensando…'),
    act: (b) =>
        b.add(TrainerChatProgressReceived(_prog('tool', tool: 'inspect_flow'))),
    expect: () => <dynamic>[
      isA<TrainerChatLoaded>().having(
        (s) => s.liveProgress,
        'progress',
        'Usando inspect_flow…',
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
      isA<TrainerChatLoaded>()
          .having((s) => s.sending, 'sending', false)
          .having(
            (s) => s.messages.where((m) => m.content == 'listo').length,
            'assistant del POST visible',
            1,
          ),
    ],
  );
}
