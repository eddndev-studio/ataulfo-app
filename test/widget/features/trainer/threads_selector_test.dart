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

class _MockRepo extends Mock implements TrainerRepository {}

TrainerConversation _conv(String id, int day, String title) =>
    TrainerConversation(
      id: id,
      templateId: 't1',
      title: title,
      createdAt: DateTime.utc(2026, 6, day),
      updatedAt: DateTime.utc(2026, 6, day),
    );

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.listConversations(templateId: 't1')).thenAnswer(
      (_) async => <TrainerConversation>[
        _conv('c2', 12, 'Sobre envíos'),
        _conv('c1', 10, 'Saludo inicial'),
      ],
    );
    when(() => repo.listModels(templateId: 't1')).thenAnswer(
      (_) async =>
          const TrainerModels(options: <TrainerModelOption>[], defaultId: ''),
    );
    when(
      () => repo.listMessages(
        templateId: 't1',
        conversationId: any(named: 'conversationId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async =>
          const TrainerMessagesPage(messages: <TrainerMessage>[], nextCursor: ''),
    );
  });

  testWidgets('el botón de hilos abre el selector con las conversaciones', (
    tester,
  ) async {
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

    await tester.tap(find.byKey(const Key('trainer.threads')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trainer.threads.list')), findsOneWidget);
    expect(find.text('Sobre envíos'), findsOneWidget);
    expect(find.text('Saludo inicial'), findsOneWidget);
    // El hilo inactivo es seleccionable.
    expect(
      find.byKey(const Key('trainer.threads.item.c1')),
      findsOneWidget,
    );
  });
}
