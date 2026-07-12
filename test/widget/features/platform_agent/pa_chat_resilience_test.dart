import 'package:ataulfo/features/platform_agent/domain/entities/pa_conversation.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_message.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_models.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_progress.dart';
import 'package:ataulfo/features/platform_agent/domain/failures/pa_failure.dart';
import 'package:ataulfo/features/platform_agent/domain/repositories/platform_agent_repository.dart';
import 'package:ataulfo/features/platform_agent/presentation/bloc/platform_agent_chat_bloc.dart';
import 'package:ataulfo/features/platform_agent/presentation/pages/platform_agent_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/chat_media_providers.dart';

class _MockRepo extends Mock implements PlatformAgentRepository {}

class _MockEvents extends Mock implements PlatformAgentEvents {}

final _conv = PaConversation(
  id: 'c1',
  title: 'Operación',
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

PaMessage _assistant(String id) => PaMessage(
  id: id,
  conversationId: 'c1',
  role: 'assistant',
  content: 'ok',
  createdAt: DateTime.utc(2026, 6, 10, 10),
);

/// Calco del homólogo del entrenador (trainer_chat_resilience_test): al cerrar
/// un turno de texto, si la recarga del hilo falla, la respuesta del POST NO se
/// pierde y la traza viva queda anclada con la marca «(traza parcial)».
void main() {
  late _MockRepo repo;
  late _MockEvents events;

  setUp(() {
    repo = _MockRepo();
    events = _MockEvents();
    when(
      () => repo.listConversations(),
    ).thenAnswer((_) async => <PaConversation>[_conv]);
    when(() => repo.listModels()).thenAnswer(
      (_) async => const PaModels(options: <PaModelOption>[], defaultId: ''),
    );
    // Carga inicial del hilo (en _onStarted): vacío.
    when(
      () => repo.listMessages(
        conversationId: 'c1',
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async =>
          const PaMessagesPage(messages: <PaMessage>[], nextCursor: ''),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: BlocProvider<PlatformAgentChatBloc>(
              create: (_) =>
                  PlatformAgentChatBloc(repo: repo, events: events)
                    ..add(const PaChatStarted()),
              child: wrapWithChatMedia(const PlatformAgentPage()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la recarga fallida marca la traza viva «(traza parcial)» '
      'sin perder la respuesta del POST', (tester) async {
    when(() => events.progress('c1')).thenAnswer(
      (_) => Stream<PaProgressEvent>.fromIterable(<PaProgressEvent>[
        PaProgressEvent(
          kind: 'tool',
          conversationId: 'c1',
          toolName: 'list_bots',
          at: DateTime.utc(2026, 6, 10, 10),
        ),
      ]),
    );
    when(
      () => repo.sendMessage(
        conversationId: 'c1',
        content: 'hola',
        model: any(named: 'model'),
        attachments: any(named: 'attachments'),
      ),
    ).thenAnswer((_) async {
      // Deja aterrizar el frame de progreso antes de cerrar el POST.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return _assistant('m9');
    });
    await pump(tester);

    await tester.enterText(find.byKey(const Key('pa.composer.field')), 'hola');
    await tester.pump();
    await tester.tap(find.byKey(const Key('pa.composer.send')));
    await tester.pump();

    // La recarga post-cierre falla: la viva queda marcada «(traza parcial)».
    when(
      () => repo.listMessages(
        conversationId: 'c1',
        limit: any(named: 'limit'),
      ),
    ).thenThrow(const PaServerFailure());
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
    expect(find.textContaining('(traza parcial)'), findsOneWidget);
    // Y la respuesta del POST sigue en el hilo pese a la recarga fallida.
    expect(find.text('ok'), findsOneWidget);
  });
}
