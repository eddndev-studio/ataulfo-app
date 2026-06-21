import 'package:ataulfo/features/platform_agent/domain/entities/pa_conversation.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_message.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_models.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_progress.dart';
import 'package:ataulfo/features/platform_agent/domain/failures/pa_failure.dart';
import 'package:ataulfo/features/platform_agent/domain/repositories/platform_agent_repository.dart';
import 'package:ataulfo/features/platform_agent/presentation/bloc/platform_agent_chat_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PlatformAgentRepository {}

class _MockEvents extends Mock implements PlatformAgentEvents {}

PaConversation _conv({String id = 'c1'}) => PaConversation(
  id: id,
  title: 'Operación',
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

PaMessage _msg(String id, String role, String content, {String conv = 'c1'}) =>
    PaMessage(
      id: id,
      conversationId: conv,
      role: role,
      content: content,
      createdAt: DateTime.utc(2026, 6, 10, 10),
    );

PaProgressEvent _prog(String kind, {String tool = '', String conv = 'c1'}) =>
    PaProgressEvent(
      kind: kind,
      conversationId: conv,
      at: DateTime.utc(2026, 6, 10, 10),
      toolName: tool,
    );

void main() {
  late _MockRepo repo;
  late _MockEvents events;

  setUp(() {
    repo = _MockRepo();
    events = _MockEvents();
    when(
      () => events.progress(any()),
    ).thenAnswer((_) => const Stream<PaProgressEvent>.empty());
    when(() => repo.listModels()).thenAnswer(
      (_) async => const PaModels(options: <PaModelOption>[], defaultId: ''),
    );
  });

  PlatformAgentChatBloc build() =>
      PlatformAgentChatBloc(repo: repo, events: events);

  PaChatLoaded loaded({
    bool sending = false,
    String liveProgress = '',
    List<PaMessage>? messages,
    List<PaModelOption> models = const <PaModelOption>[],
    String selectedModelId = '',
  }) => PaChatLoaded(
    conversations: <PaConversation>[_conv()],
    activeConversation: _conv(),
    messages: messages ?? const <PaMessage>[],
    sending: sending,
    liveProgress: liveProgress,
    models: models,
    selectedModelId: selectedModelId,
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'Started: reanuda el hilo más reciente y carga mensajes en ASC',
    build: build,
    setUp: () {
      when(
        () => repo.listConversations(),
      ).thenAnswer((_) async => <PaConversation>[_conv()]);
      when(
        () => repo.listMessages(
          conversationId: 'c1',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => PaMessagesPage(
          // wire DESC; el bloc invierte a ASC.
          messages: <PaMessage>[
            _msg('m2', 'assistant', 'tienes 3 bots'),
            _msg('m1', 'user', 'cuántos bots'),
          ],
          nextCursor: '',
        ),
      );
    },
    act: (b) => b.add(const PaChatStarted()),
    expect: () => <dynamic>[
      const PaChatLoading(),
      isA<PaChatLoaded>()
          .having((s) => s.activeConversation.id, 'active', 'c1')
          .having((s) => s.messages.first.id, 'primero ASC', 'm1')
          .having((s) => s.sending, 'sending', false),
    ],
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'Started sin hilos: crea uno nuevo',
    build: build,
    setUp: () {
      when(
        () => repo.listConversations(),
      ).thenAnswer((_) async => <PaConversation>[]);
      when(
        () => repo.createConversation(title: any(named: 'title')),
      ).thenAnswer((_) async => _conv());
      when(
        () => repo.listMessages(
          conversationId: 'c1',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async =>
            const PaMessagesPage(messages: <PaMessage>[], nextCursor: ''),
      );
    },
    act: (b) => b.add(const PaChatStarted()),
    verify: (_) {
      verify(
        () => repo.createConversation(title: any(named: 'title')),
      ).called(1);
    },
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'Started con fallo ⇒ PaChatFailed',
    build: build,
    setUp: () {
      when(() => repo.listConversations()).thenThrow(const PaServerFailure());
    },
    act: (b) => b.add(const PaChatStarted()),
    expect: () => <dynamic>[const PaChatLoading(), isA<PaChatFailed>()],
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'MessageSent: optimista (sending+Pensando…) y luego recarga el hilo',
    build: build,
    seed: () => loaded(),
    setUp: () {
      when(
        () => repo.sendMessage(
          conversationId: 'c1',
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async => _msg('m9', 'assistant', 'tienes 3 bots'));
      when(
        () => repo.listMessages(
          conversationId: 'c1',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => PaMessagesPage(
          messages: <PaMessage>[
            _msg('m9', 'assistant', 'tienes 3 bots'),
            _msg('m8', 'user', 'cuántos bots'),
          ],
          nextCursor: '',
        ),
      );
    },
    act: (b) => b.add(const PaChatMessageSent('cuántos bots')),
    expect: () => <dynamic>[
      isA<PaChatLoaded>()
          .having((s) => s.sending, 'sending', true)
          .having((s) => s.liveProgress, 'progress', 'Pensando…')
          .having((s) => s.messages.last.content, 'optimista', 'cuántos bots'),
      isA<PaChatLoaded>()
          .having((s) => s.sending, 'sending', false)
          .having((s) => s.liveProgress, 'progress', '')
          .having(
            (s) => s.messages.any((m) => m.isAssistant),
            'tiene assistant',
            true,
          ),
    ],
    verify: (_) {
      verify(() => events.progress('c1')).called(1);
    },
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'MessageSent: recarga rezagada (sin el turno) — el assistant del POST igual aparece',
    build: build,
    seed: () => loaded(),
    setUp: () {
      when(
        () => repo.sendMessage(
          conversationId: 'c1',
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async => _msg('m9', 'assistant', 'tienes 3 bots'));
      // Carrera read-after-write: la recarga aún no ve el turno recién escrito.
      when(
        () => repo.listMessages(
          conversationId: 'c1',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async =>
            const PaMessagesPage(messages: <PaMessage>[], nextCursor: ''),
      );
    },
    act: (b) => b.add(const PaChatMessageSent('cuántos bots')),
    expect: () => <dynamic>[
      isA<PaChatLoaded>().having((s) => s.sending, 'sending', true),
      isA<PaChatLoaded>()
          .having((s) => s.sending, 'sending', false)
          .having(
            (s) => s.messages.where((m) => m.content == 'tienes 3 bots').length,
            'assistant del POST visible',
            1,
          )
          .having(
            (s) => s.messages.where((m) => m.content == 'cuántos bots').length,
            'user conservado',
            1,
          ),
    ],
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'MessageSent: recarga FALLA tras turno OK — conserva la respuesta, sin sendFailure',
    build: build,
    seed: () => loaded(),
    setUp: () {
      when(
        () => repo.sendMessage(
          conversationId: 'c1',
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async => _msg('m9', 'assistant', 'tienes 3 bots'));
      when(
        () => repo.listMessages(
          conversationId: 'c1',
          limit: any(named: 'limit'),
        ),
      ).thenThrow(const PaServerFailure());
    },
    act: (b) => b.add(const PaChatMessageSent('cuántos bots')),
    expect: () => <dynamic>[
      isA<PaChatLoaded>().having((s) => s.sending, 'sending', true),
      isA<PaChatLoaded>()
          .having((s) => s.sending, 'sending', false)
          .having((s) => s.sendFailure, 'sin fallo (el turno fue OK)', isNull)
          .having(
            (s) => s.messages.where((m) => m.content == 'tienes 3 bots').length,
            'assistant conservado',
            1,
          ),
    ],
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'MessageSent con 502 ⇒ sending=false + sendFailure',
    build: build,
    seed: () => loaded(),
    setUp: () {
      when(
        () => repo.sendMessage(
          conversationId: 'c1',
          content: any(named: 'content'),
        ),
      ).thenThrow(const PaEngineFailure());
    },
    act: (b) => b.add(const PaChatMessageSent('x')),
    expect: () => <dynamic>[
      isA<PaChatLoaded>().having((s) => s.sending, 'sending', true),
      isA<PaChatLoaded>()
          .having((s) => s.sending, 'sending', false)
          .having((s) => s.sendFailure, 'failure', isA<PaEngineFailure>()),
    ],
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'ProgressReceived(tool) mientras sending actualiza el indicador',
    build: build,
    seed: () => loaded(sending: true, liveProgress: 'Pensando…'),
    act: (b) => b.add(PaChatProgressReceived(_prog('tool', tool: 'list_bots'))),
    expect: () => <dynamic>[
      isA<PaChatLoaded>().having(
        (s) => s.liveProgress,
        'progress',
        'Usando list_bots…',
      ),
    ],
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'NewConversationRequested: crea hilo, lo activa y lo antepone a la lista',
    build: build,
    seed: () => loaded(),
    setUp: () {
      when(
        () => repo.createConversation(title: any(named: 'title')),
      ).thenAnswer((_) async => _conv(id: 'c2'));
    },
    act: (b) => b.add(const PaChatNewConversationRequested()),
    expect: () => <dynamic>[
      isA<PaChatLoaded>()
          .having((s) => s.activeConversation.id, 'active', 'c2')
          .having((s) => s.messages, 'vacío', isEmpty)
          .having((s) => s.conversations.first.id, 'lista primero', 'c2'),
    ],
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'ConversationSelected: cambia el activo y carga sus mensajes',
    build: build,
    seed: () => PaChatLoaded(
      conversations: <PaConversation>[
        _conv(),
        _conv(id: 'c2'),
      ],
      activeConversation: _conv(),
      messages: const <PaMessage>[],
      sending: false,
      liveProgress: '',
    ),
    setUp: () {
      when(
        () => repo.listMessages(
          conversationId: 'c2',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => PaMessagesPage(
          messages: <PaMessage>[_msg('mz', 'assistant', 'hola c2', conv: 'c2')],
          nextCursor: '',
        ),
      );
    },
    act: (b) => b.add(const PaChatConversationSelected('c2')),
    expect: () => <dynamic>[
      isA<PaChatLoaded>()
          .having((s) => s.activeConversation.id, 'active', 'c2')
          .having((s) => s.messages.single.content, 'mensajes c2', 'hola c2'),
    ],
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'Started carga la allowlist de modelos en Loaded',
    build: build,
    setUp: () {
      when(
        () => repo.listConversations(),
      ).thenAnswer((_) async => <PaConversation>[_conv()]);
      when(
        () => repo.listMessages(
          conversationId: 'c1',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async =>
            const PaMessagesPage(messages: <PaMessage>[], nextCursor: ''),
      );
      when(() => repo.listModels()).thenAnswer(
        (_) async => const PaModels(
          options: <PaModelOption>[
            PaModelOption(id: 'gpt-5.5', label: 'ChatGPT 5.5'),
          ],
          defaultId: 'gemini-3.1-pro-preview',
        ),
      );
    },
    act: (b) => b.add(const PaChatStarted()),
    expect: () => <dynamic>[
      const PaChatLoading(),
      isA<PaChatLoaded>()
          .having((s) => s.models.single.id, 'modelo', 'gpt-5.5')
          .having((s) => s.defaultModelId, 'default', 'gemini-3.1-pro-preview'),
    ],
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'ModelSelected fija el modelo elegido',
    build: build,
    seed: () => loaded(
      models: const <PaModelOption>[
        PaModelOption(id: 'gpt-5.5', label: 'ChatGPT 5.5'),
      ],
    ),
    act: (b) => b.add(const PaChatModelSelected('gpt-5.5')),
    expect: () => <dynamic>[
      isA<PaChatLoaded>().having((s) => s.selectedModelId, 'sel', 'gpt-5.5'),
    ],
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'MessageSent manda el modelo elegido; vacío lo omite (null)',
    build: build,
    seed: () => loaded(selectedModelId: 'gpt-5.5'),
    setUp: () {
      when(
        () => repo.sendMessage(
          conversationId: any(named: 'conversationId'),
          content: any(named: 'content'),
          model: any(named: 'model'),
        ),
      ).thenAnswer((_) async => _msg('m9', 'assistant', 'ok'));
      when(
        () => repo.listMessages(
          conversationId: 'c1',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async =>
            const PaMessagesPage(messages: <PaMessage>[], nextCursor: ''),
      );
    },
    act: (b) => b.add(const PaChatMessageSent('hola')),
    verify: (_) {
      verify(
        () => repo.sendMessage(
          conversationId: 'c1',
          content: 'hola',
          model: 'gpt-5.5',
        ),
      ).called(1);
    },
  );
}
