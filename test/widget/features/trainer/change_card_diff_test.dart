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

/// Arma el toolResults ANIDADO real del wire: content es un STRING JSON con
/// el envelope de la tool (así lo persiste el server).
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

  testWidgets('la tarjeta con diff se expande y muestra old/new + contexto', (
    tester,
  ) async {
    await pump(tester, <TrainerMessage>[
      _toolMsg(
        'm2',
        _toolResults('edit_doc', <String, Object?>{
          'status': 'updated',
          'name': 'politicas',
          'diff': <String, String>{
            'old': 'envíos en 48h',
            'new': 'envíos en 24h',
            'context': 'línea uno\nenvíos en 48h\nlínea tres',
          },
        }),
      ),
    ]);

    // Colapsada: título + affordance de expandir; el diff aún no se pinta.
    expect(find.byKey(const Key('trainer.change_card.m2')), findsOneWidget);
    expect(
      find.byKey(const Key('trainer.change_card.m2.expand')),
      findsOneWidget,
    );
    expect(find.textContaining('envíos en 48h'), findsNothing);

    await tester.tap(find.byKey(const Key('trainer.change_card.m2')));
    await tester.pumpAndSettle();

    // Expandida: nombre del doc + bloques old/new.
    expect(find.textContaining('politicas'), findsOneWidget);
    expect(find.textContaining('envíos en 48h'), findsOneWidget);
    expect(find.textContaining('envíos en 24h'), findsOneWidget);

    // Colapsa de vuelta.
    await tester.tap(find.byKey(const Key('trainer.change_card.m2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('envíos en 48h'), findsNothing);
  });

  testWidgets('un envelope viejo SIN diff degrada a la tarjeta plana', (
    tester,
  ) async {
    await pump(tester, <TrainerMessage>[
      _toolMsg(
        'm2',
        _toolResults('edit_prompt', <String, Object?>{'status': 'updated'}),
      ),
    ]);

    expect(find.byKey(const Key('trainer.change_card.m2')), findsOneWidget);
    expect(
      find.byKey(const Key('trainer.change_card.m2.expand')),
      findsNothing,
    );
    // Tap no debe romper nada (no hay nada que expandir).
    await tester.tap(find.byKey(const Key('trainer.change_card.m2')));
    await tester.pumpAndSettle();
  });

  testWidgets('write_doc sin diff muestra el nombre creado al expandir', (
    tester,
  ) async {
    await pump(tester, <TrainerMessage>[
      _toolMsg(
        'm2',
        _toolResults('write_doc', <String, Object?>{
          'status': 'created',
          'name': 'horarios',
          'bytes': 320,
        }),
      ),
    ]);

    expect(
      find.byKey(const Key('trainer.change_card.m2.expand')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('trainer.change_card.m2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('horarios'), findsOneWidget);
  });
}
