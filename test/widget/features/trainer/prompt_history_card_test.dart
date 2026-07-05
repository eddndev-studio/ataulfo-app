import 'dart:convert';

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

import '../../../support/chat_media_providers.dart';

class _MockTrainerRepo extends Mock implements TrainerRepository {}

final _conv = TrainerConversation(
  id: 'c1',
  templateId: 't1',
  title: 'Entrenamiento',
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

String _toolResults(String tool, Map<String, Object?> envelope) =>
    jsonEncode(<String, Object?>{
      'toolName': tool,
      'toolCallId': 'tc1',
      'content': jsonEncode(envelope),
    });

TrainerMessage _toolMsg(String id, String raw) => TrainerMessage(
  id: id,
  conversationId: 'c1',
  role: 'tool',
  content: '',
  toolResultsRaw: raw,
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
          child: wrapWithChatMedia(const TrainerChatPage(templateId: 't1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('list_prompt_history rinde la tarjeta y revela las versiones', (
    tester,
  ) async {
    await pump(tester, <TrainerMessage>[
      _toolMsg(
        'm1',
        _toolResults('list_prompt_history', <String, Object?>{
          'available': true,
          'versions': <Object?>[
            <String, Object?>{
              'id': 9,
              'created_at': '2026-06-10T10:00:00.000Z',
              'preview': 'prompt anterior',
              'size_bytes': 15,
            },
          ],
        }),
      ),
    ]);
    expect(
      find.byKey(const Key('trainer.prompt_history_card.m1')),
      findsOneWidget,
    );
    // Colapsado: el preview no se ve aún.
    expect(find.textContaining('prompt anterior'), findsNothing);
    await tester.tap(find.byKey(const Key('trainer.prompt_history_card.m1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('prompt anterior'), findsOneWidget);
    expect(find.textContaining('9'), findsWidgets); // el id de la versión
  });

  testWidgets(
    'list_prompt_history con error NO se enmascara como "sin versiones"',
    (tester) async {
      await pump(tester, <TrainerMessage>[
        _toolMsg(
          'm1',
          _toolResults('list_prompt_history', <String, Object?>{
            'error_kind': 'builtin_error',
            'detail': 'db caída',
          }),
        ),
      ]);
      // Un fallo del tool debe caer a la tarjeta de error, no a la de historial.
      expect(
        find.byKey(const Key('trainer.prompt_history_card.m1')),
        findsNothing,
      );
      expect(find.textContaining('sin versiones'), findsNothing);
    },
  );
}
