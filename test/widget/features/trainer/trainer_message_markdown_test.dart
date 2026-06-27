import 'package:ataulfo/core/design/widgets/assistant_markdown.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_conversation.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_models.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/trainer_chat_bloc.dart';
import 'package:ataulfo/features/trainer/presentation/pages/trainer_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrainerRepo extends Mock implements TrainerRepository {}

final _conv = TrainerConversation(
  id: 'c1',
  templateId: 't1',
  title: 'Entrenamiento',
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

TrainerMessage _textMsg(String id, String role, String content) =>
    TrainerMessage(
      id: id,
      conversationId: 'c1',
      role: role,
      content: content,
      createdAt: DateTime.utc(2026, 6, 10, 10),
    );

void main() {
  late _MockTrainerRepo repo;

  setUp(() {
    repo = _MockTrainerRepo();
    when(
      () => repo.listConversations(templateId: 't1'),
    ).thenAnswer((_) async => <TrainerConversation>[_conv]);
    when(() => repo.listModels(templateId: 't1')).thenAnswer(
      (_) async =>
          const TrainerModels(options: <TrainerModelOption>[], defaultId: ''),
    );
  });

  Future<void> pump(WidgetTester tester, List<TrainerMessage> msgs) async {
    when(
      () => repo.listMessages(
        templateId: 't1',
        conversationId: 'c1',
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async =>
          TrainerMessagesPage(messages: msgs.reversed.toList(), nextCursor: ''),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<TrainerChatBloc>(
          create: (_) =>
              TrainerChatBloc(repo: repo, templateId: 't1')
                ..add(const TrainerChatStarted()),
          child: const TrainerChatPage(templateId: 't1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('burbuja assistant rinde Markdown', (tester) async {
    await pump(tester, <TrainerMessage>[
      _textMsg('m1', 'assistant', '**negrita**'),
    ]);
    expect(find.byType(AssistantMarkdown), findsOneWidget);
  });

  testWidgets('burbuja user queda en Text plano (sin Markdown)', (
    tester,
  ) async {
    await pump(tester, <TrainerMessage>[_textMsg('m1', 'user', '**negrita**')]);
    expect(find.byType(AssistantMarkdown), findsNothing);
    expect(find.text('**negrita**'), findsOneWidget);
  });
}
