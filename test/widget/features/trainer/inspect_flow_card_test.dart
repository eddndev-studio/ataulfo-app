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

  Map<String, Object?> inspectEnvelope() => <String, Object?>{
    'id': 'f-1',
    'name': 'Bienvenida',
    'is_active': true,
    'steps': <Object?>[
      <String, Object?>{
        'id': 's1',
        'type': 'TEXT',
        'order': 0,
        'content': 'Hola, ¿en qué te ayudo?',
      },
      <String, Object?>{
        'id': 's2',
        'type': 'IMAGE',
        'order': 1,
        'media_ref': 'img1',
      },
    ],
    'triggers': <Object?>[
      <String, Object?>{
        'id': 'tr1',
        'trigger_type': 'TEXT',
        'keyword': 'hola',
        'scope': 'BOTH',
        'is_active': true,
      },
    ],
  };

  testWidgets(
    'inspect_flow: colapsado muestra el flujo; al expandir, pasos y triggers',
    (tester) async {
      await pump(tester, <TrainerMessage>[
        _toolMsg('m3', _toolResults('inspect_flow', inspectEnvelope())),
      ]);

      // El proceso vive plegado en la traza del turno; expandirla revela la
      // tarjeta como cuerpo del nodo.
      expect(find.byKey(const Key('trainer.inspect_card.m3')), findsNothing);
      await tester.tap(find.text('Usó herramientas'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trainer.inspect_card.m3')), findsOneWidget);
      expect(find.textContaining('Bienvenida'), findsOneWidget);
      // Colapsado: el contenido de los pasos aún no se ve.
      expect(find.textContaining('¿en qué te ayudo'), findsNothing);

      await tester.tap(find.byKey(const Key('trainer.inspect_card.m3')));
      await tester.pumpAndSettle();

      expect(find.textContaining('¿en qué te ayudo'), findsOneWidget);
      expect(
        find.textContaining('hola'),
        findsWidgets,
      ); // keyword del disparador
    },
  );
}
