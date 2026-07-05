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

  testWidgets('un envelope de error de tool se muestra como tarjeta de error', (
    tester,
  ) async {
    await pump(tester, <TrainerMessage>[
      _toolMsg(
        'm4',
        _toolResults('edit_prompt', <String, Object?>{
          'error_kind': 'anchor_not_found',
        }),
      ),
    ]);
    expect(find.byKey(const Key('trainer.error_card.m4')), findsOneWidget);
    // Copy legible en español para anchor_not_found (menciona el ancla).
    expect(find.textContaining('ancla'), findsOneWidget);
  });

  testWidgets('variable_in_use se traduce a copy legible', (tester) async {
    await pump(tester, <TrainerMessage>[
      _toolMsg(
        'm5',
        _toolResults('remove_variable', <String, Object?>{
          'error_kind': 'variable_in_use',
        }),
      ),
    ]);
    expect(find.byKey(const Key('trainer.error_card.m5')), findsOneWidget);
    expect(find.textContaining('en uso'), findsOneWidget);
  });
}
