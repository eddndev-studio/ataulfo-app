import 'package:ataulfo/features/trainer/domain/entities/preview_item.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_conversation.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/domain/entities/workspace_doc.dart';
import 'package:ataulfo/features/trainer/domain/failures/trainer_failure.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/preview_bloc.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/trainer_chat_bloc.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/workspace_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrainerRepo extends Mock implements TrainerRepository {}

class _MockWorkspaceRepo extends Mock implements WorkspaceRepository {}

class _MockPreviewRepo extends Mock implements PreviewRepository {}

final _conv = TrainerConversation(
  id: 'c1',
  templateId: 't1',
  title: 'Entrenamiento',
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

TrainerMessage _msg(String id, String role, String content) => TrainerMessage(
  id: id,
  conversationId: 'c1',
  role: role,
  content: content,
  createdAt: DateTime.utc(2026, 6, 10, 10),
);

final _doc = WorkspaceDoc(
  name: 'menu',
  content: 'Tacos \$25',
  sizeBytes: 9,
  updatedByKind: 'trainer',
  version: 1,
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

PreviewItem _item(String kind, {String text = '', String summary = ''}) =>
    PreviewItem(
      kind: kind,
      text: text,
      summary: summary,
      at: DateTime.utc(2026, 6, 10),
    );

void main() {
  group('TrainerChatBloc', () {
    late _MockTrainerRepo repo;
    setUp(() => repo = _MockTrainerRepo());

    TrainerChatBloc build() => TrainerChatBloc(repo: repo, templateId: 't1');

    blocTest<TrainerChatBloc, TrainerChatState>(
      'Started: reanuda el hilo más reciente y carga mensajes en ASC',
      build: build,
      setUp: () {
        when(
          () => repo.listConversations(templateId: 't1'),
        ).thenAnswer((_) async => <TrainerConversation>[_conv]);
        when(
          () => repo.listMessages(
            templateId: 't1',
            conversationId: 'c1',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => TrainerMessagesPage(
            // El wire entrega DESC; el bloc invierte a ASC para el hilo.
            messages: <TrainerMessage>[
              _msg('m2', 'assistant', 'te ayudo'),
              _msg('m1', 'user', 'hola'),
            ],
            nextCursor: '',
          ),
        );
      },
      act: (b) => b.add(const TrainerChatStarted()),
      expect: () => <dynamic>[
        const TrainerChatLoading(),
        isA<TrainerChatLoaded>()
            .having((s) => s.conversation.id, 'conv', 'c1')
            .having((s) => s.messages.first.id, 'primero ASC', 'm1')
            .having((s) => s.sending, 'sending', false),
      ],
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'Started sin hilos: crea uno nuevo',
      build: build,
      setUp: () {
        when(
          () => repo.listConversations(templateId: 't1'),
        ).thenAnswer((_) async => <TrainerConversation>[]);
        when(
          () => repo.createConversation(
            templateId: 't1',
            title: any(named: 'title'),
          ),
        ).thenAnswer((_) async => _conv);
        when(
          () => repo.listMessages(
            templateId: 't1',
            conversationId: 'c1',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => const TrainerMessagesPage(
            messages: <TrainerMessage>[],
            nextCursor: '',
          ),
        );
      },
      act: (b) => b.add(const TrainerChatStarted()),
      verify: (_) {
        verify(
          () => repo.createConversation(
            templateId: 't1',
            title: any(named: 'title'),
          ),
        ).called(1);
      },
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'MessageSent: optimista + typing, luego recarga del server',
      build: build,
      seed: () => TrainerChatLoaded(
        conversation: _conv,
        messages: <TrainerMessage>[_msg('m1', 'user', 'hola')],
        sending: false,
      ),
      setUp: () {
        when(
          () => repo.sendMessage(
            templateId: 't1',
            conversationId: 'c1',
            content: 'mejora el prompt',
          ),
        ).thenAnswer((_) async => _msg('m3', 'assistant', 'hecho'));
        when(
          () => repo.listMessages(
            templateId: 't1',
            conversationId: 'c1',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => TrainerMessagesPage(
            messages: <TrainerMessage>[
              _msg('m3', 'assistant', 'hecho'),
              _msg('m2', 'user', 'mejora el prompt'),
              _msg('m1', 'user', 'hola'),
            ],
            nextCursor: '',
          ),
        );
      },
      act: (b) => b.add(const TrainerChatMessageSent('mejora el prompt')),
      expect: () => <dynamic>[
        isA<TrainerChatLoaded>()
            .having((s) => s.sending, 'typing visible', true)
            .having(
              (s) => s.messages.last.content,
              'optimista',
              'mejora el prompt',
            ),
        isA<TrainerChatLoaded>()
            .having((s) => s.sending, 'sending off', false)
            .having((s) => s.messages.length, 'recargado', 3),
      ],
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'MessageSent con motor caído: revierte el optimista y expone el fallo',
      build: build,
      seed: () => TrainerChatLoaded(
        conversation: _conv,
        messages: <TrainerMessage>[_msg('m1', 'user', 'hola')],
        sending: false,
      ),
      setUp: () {
        when(
          () => repo.sendMessage(
            templateId: 't1',
            conversationId: 'c1',
            content: 'x',
          ),
        ).thenThrow(const TrainerEngineFailure());
      },
      act: (b) => b.add(const TrainerChatMessageSent('x')),
      expect: () => <dynamic>[
        isA<TrainerChatLoaded>().having((s) => s.sending, 'typing', true),
        isA<TrainerChatLoaded>()
            .having((s) => s.sending, 'off', false)
            .having((s) => s.messages.length, 'optimista revertido', 1)
            .having(
              (s) => s.sendFailure,
              'fallo expuesto',
              isA<TrainerEngineFailure>(),
            ),
      ],
    );
  });

  group('WorkspaceBloc', () {
    late _MockWorkspaceRepo repo;
    setUp(() => repo = _MockWorkspaceRepo());

    WorkspaceBloc build() => WorkspaceBloc(repo: repo, templateId: 't1');

    blocTest<WorkspaceBloc, WorkspaceState>(
      'Load lista los docs',
      build: build,
      setUp: () {
        when(
          () => repo.listDocs(templateId: 't1'),
        ).thenAnswer((_) async => <WorkspaceDoc>[_doc]);
      },
      act: (b) => b.add(const WorkspaceLoadRequested()),
      expect: () => <dynamic>[
        const WorkspaceLoading(),
        isA<WorkspaceLoaded>().having((s) => s.docs.length, 'docs', 1),
      ],
    );

    blocTest<WorkspaceBloc, WorkspaceState>(
      'Create con 409 (duplicado): expone fallo sin perder el snapshot',
      build: build,
      seed: () => WorkspaceLoaded(docs: <WorkspaceDoc>[_doc], mutating: false),
      setUp: () {
        when(
          () => repo.createDoc(templateId: 't1', name: 'menu', content: 'x'),
        ).thenThrow(const TrainerConflictFailure());
      },
      act: (b) => b.add(const WorkspaceDocCreated(name: 'menu', content: 'x')),
      expect: () => <dynamic>[
        isA<WorkspaceLoaded>().having((s) => s.mutating, 'mutating', true),
        isA<WorkspaceLoaded>()
            .having((s) => s.mutating, 'off', false)
            .having((s) => s.docs.length, 'snapshot intacto', 1)
            .having(
              (s) => s.mutationFailure,
              'fallo',
              isA<TrainerConflictFailure>(),
            ),
      ],
    );

    blocTest<WorkspaceBloc, WorkspaceState>(
      'Update feliz recarga del server',
      build: build,
      seed: () => WorkspaceLoaded(docs: <WorkspaceDoc>[_doc], mutating: false),
      setUp: () {
        when(
          () => repo.updateDoc(
            templateId: 't1',
            name: 'menu',
            content: 'nuevo',
            version: 1,
          ),
        ).thenAnswer((_) async => _doc);
        when(
          () => repo.listDocs(templateId: 't1'),
        ).thenAnswer((_) async => <WorkspaceDoc>[_doc, _doc]);
      },
      act: (b) => b.add(
        const WorkspaceDocUpdated(name: 'menu', content: 'nuevo', version: 1),
      ),
      expect: () => <dynamic>[
        isA<WorkspaceLoaded>().having((s) => s.mutating, 'mutating', true),
        isA<WorkspaceLoaded>()
            .having((s) => s.mutating, 'off', false)
            .having((s) => s.docs.length, 'recargado', 2),
      ],
    );
  });

  group('PreviewBloc', () {
    late _MockPreviewRepo repo;
    setUp(() => repo = _MockPreviewRepo());

    PreviewBloc build() => PreviewBloc(repo: repo, templateId: 't1');

    blocTest<PreviewBloc, PreviewState>(
      'Started rehidrata el transcript vivo',
      build: build,
      setUp: () {
        when(
          () => repo.transcript(templateId: 't1'),
        ).thenAnswer((_) async => <PreviewItem>[_item('user', text: 'hola')]);
      },
      act: (b) => b.add(const PreviewStarted()),
      expect: () => <dynamic>[
        const PreviewLoading(),
        isA<PreviewLoaded>().having((s) => s.items.length, 'items', 1),
      ],
    );

    blocTest<PreviewBloc, PreviewState>(
      'MessageSent agrega los items del turno (burbujas + chips)',
      build: build,
      seed: () => const PreviewLoaded(items: <PreviewItem>[], sending: false),
      setUp: () {
        when(
          () => repo.sendMessage(templateId: 't1', content: 'hola'),
        ).thenAnswer(
          (_) async => PreviewTurn(
            items: <PreviewItem>[
              _item('user', text: 'hola'),
              _item('bot', text: '¡Hola!'),
              _item('action', summary: 'Etiquetaría: VIP'),
            ],
            iterations: 2,
          ),
        );
      },
      act: (b) => b.add(const PreviewMessageSent('hola')),
      expect: () => <dynamic>[
        isA<PreviewLoaded>().having((s) => s.sending, 'typing', true),
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'off', false)
            .having((s) => s.items.length, 'turno agregado', 3),
      ],
    );

    blocTest<PreviewBloc, PreviewState>(
      'Reset limpia la sesión',
      build: build,
      seed: () => PreviewLoaded(
        items: <PreviewItem>[_item('user', text: 'a')],
        sending: false,
      ),
      setUp: () {
        when(() => repo.reset(templateId: 't1')).thenAnswer((_) async {});
      },
      act: (b) => b.add(const PreviewResetRequested()),
      expect: () => <dynamic>[
        isA<PreviewLoaded>().having((s) => s.items, 'vacío', isEmpty),
      ],
    );

    blocTest<PreviewBloc, PreviewState>(
      '503 sin sandbox expone fallo claro',
      build: build,
      seed: () => const PreviewLoaded(items: <PreviewItem>[], sending: false),
      setUp: () {
        when(
          () => repo.sendMessage(templateId: 't1', content: 'x'),
        ).thenThrow(const TrainerUnavailableFailure());
      },
      act: (b) => b.add(const PreviewMessageSent('x')),
      expect: () => <dynamic>[
        isA<PreviewLoaded>().having((s) => s.sending, 'typing', true),
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'off', false)
            .having(
              (s) => s.failure,
              'fallo',
              isA<TrainerUnavailableFailure>(),
            ),
      ],
    );
  });
}
