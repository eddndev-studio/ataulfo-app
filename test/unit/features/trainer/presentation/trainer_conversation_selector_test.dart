import 'package:ataulfo/features/trainer/domain/entities/trainer_conversation.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_models.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/trainer_chat_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements TrainerRepository {}

TrainerConversation _conv(String id, int day) => TrainerConversation(
  id: id,
  templateId: 't1',
  title: 'Hilo $id',
  createdAt: DateTime.utc(2026, 6, day),
  updatedAt: DateTime.utc(2026, 6, day),
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(
      () => repo.listModels(templateId: any(named: 'templateId')),
    ).thenAnswer(
      (_) async =>
          const TrainerModels(options: <TrainerModelOption>[], defaultId: ''),
    );
    when(
      () => repo.listMessages(
        templateId: any(named: 'templateId'),
        conversationId: any(named: 'conversationId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((inv) async {
      final cid = inv.namedArguments[#conversationId] as String;
      return TrainerMessagesPage(
        messages: <TrainerMessage>[
          TrainerMessage(
            id: 'm-$cid',
            conversationId: cid,
            role: 'assistant',
            content: 'mensaje de $cid',
            createdAt: DateTime.utc(2026, 6, 10),
          ),
        ],
        nextCursor: '',
      );
    });
  });

  TrainerChatBloc build() => TrainerChatBloc(repo: repo, templateId: 't1');

  blocTest<TrainerChatBloc, TrainerChatState>(
    'Started expone la lista de conversaciones y activa la primera',
    build: build,
    setUp: () {
      when(() => repo.listConversations(templateId: 't1')).thenAnswer(
        (_) async => <TrainerConversation>[_conv('c2', 12), _conv('c1', 10)],
      );
    },
    act: (b) => b.add(const TrainerChatStarted()),
    expect: () => <dynamic>[
      isA<TrainerChatLoading>(),
      isA<TrainerChatLoaded>()
          .having((s) => s.conversations.length, 'lista', 2)
          .having((s) => s.conversation.id, 'activa', 'c2'),
    ],
  );

  blocTest<TrainerChatBloc, TrainerChatState>(
    'ConversationSelected cambia el hilo activo y carga sus mensajes',
    build: build,
    setUp: () {
      when(() => repo.listConversations(templateId: 't1')).thenAnswer(
        (_) async => <TrainerConversation>[_conv('c2', 12), _conv('c1', 10)],
      );
    },
    act: (b) async {
      b.add(const TrainerChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const TrainerChatConversationSelected('c1'));
    },
    skip: 2, // los 2 estados del Started
    expect: () => <dynamic>[
      isA<TrainerChatLoaded>()
          .having((s) => s.conversation.id, 'activa', 'c1')
          .having((s) => s.messages.first.content, 'mensajes', 'mensaje de c1'),
    ],
  );
}
