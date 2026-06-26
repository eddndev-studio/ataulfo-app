import 'dart:async';

import 'package:ataulfo/features/trainer/domain/entities/trainer_conversation.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_models.dart';
import 'package:ataulfo/features/trainer/domain/failures/trainer_failure.dart';
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

TrainerMessage _assistant(String id) => TrainerMessage(
  id: id,
  conversationId: 'c1',
  role: 'assistant',
  content: 'ok',
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
  });

  Future<void> pump(WidgetTester tester) async {
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

  testWidgets('fallo: muestra "Reintentar", restaura el composer y reenvía', (
    tester,
  ) async {
    when(
      () => repo.sendMessage(
        templateId: 't1',
        conversationId: 'c1',
        content: 'mejora el prompt',
        attachments: any(named: 'attachments'),
      ),
    ).thenThrow(const TrainerEngineFailure());
    await pump(tester);

    await tester.enterText(
      find.byKey(const Key('trainer.composer.field')),
      'mejora el prompt',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('trainer.composer.send')));
    await tester.pumpAndSettle();

    // Tira accionable + composer recuperado con el texto enviado.
    expect(find.byKey(const Key('trainer.send_failure.retry')), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('trainer.composer.field')),
    );
    expect(field.controller?.text, 'mejora el prompt');

    // Reintentar re-despacha el mismo texto (esta vez OK).
    when(
      () => repo.sendMessage(
        templateId: 't1',
        conversationId: 'c1',
        content: 'mejora el prompt',
        attachments: any(named: 'attachments'),
      ),
    ).thenAnswer((_) async => _assistant('m9'));
    await tester.tap(find.byKey(const Key('trainer.send_failure.retry')));
    await tester.pumpAndSettle();
    verify(
      () => repo.sendMessage(
        templateId: 't1',
        conversationId: 'c1',
        content: 'mejora el prompt',
        attachments: any(named: 'attachments'),
      ),
    ).called(2);
  });

  testWidgets('turno en vuelo: "Detener" cancela y limpia el estado', (
    tester,
  ) async {
    final hang = Completer<TrainerMessage>();
    when(
      () => repo.sendMessage(
        templateId: 't1',
        conversationId: 'c1',
        content: 'hola',
        attachments: any(named: 'attachments'),
      ),
    ).thenAnswer((_) => hang.future);
    when(() => repo.cancelSend()).thenAnswer((_) {
      if (!hang.isCompleted) hang.completeError(const TrainerUnknownFailure());
    });
    await pump(tester);

    await tester.enterText(
      find.byKey(const Key('trainer.composer.field')),
      'hola',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('trainer.composer.send')));
    await tester.pump();

    expect(find.byKey(const Key('trainer.turn_cancel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('trainer.turn_cancel')));
    await tester.pumpAndSettle();

    verify(() => repo.cancelSend()).called(1);
    expect(find.byKey(const Key('trainer.turn_cancel')), findsNothing);
  });
}
