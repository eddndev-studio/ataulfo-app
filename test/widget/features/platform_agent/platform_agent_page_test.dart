import 'package:ataulfo/features/platform_agent/domain/entities/pa_conversation.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_message.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_models.dart';
import 'package:ataulfo/features/platform_agent/domain/failures/pa_failure.dart';
import 'package:ataulfo/features/platform_agent/presentation/bloc/platform_agent_chat_bloc.dart';
import 'package:ataulfo/features/platform_agent/presentation/pages/platform_agent_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<PaChatEvent, PaChatState>
    implements PlatformAgentChatBloc {}

PaConversation _conv({String id = 'c1', String title = 'Operación'}) =>
    PaConversation(
      id: id,
      title: title,
      createdAt: DateTime.utc(2026, 6, 10),
      updatedAt: DateTime.utc(2026, 6, 10),
    );

PaMessage _msg(String id, String role, String content) => PaMessage(
  id: id,
  conversationId: 'c1',
  role: role,
  content: content,
  createdAt: DateTime.utc(2026, 6, 10, 10),
);

PaChatLoaded _loaded({
  bool sending = false,
  String liveProgress = '',
  PaFailure? sendFailure,
  List<PaMessage>? messages,
  List<PaConversation>? conversations,
  List<PaModelOption> models = const <PaModelOption>[],
  String selectedModelId = '',
}) => PaChatLoaded(
  conversations: conversations ?? <PaConversation>[_conv()],
  activeConversation: _conv(),
  messages: messages ?? <PaMessage>[_msg('m1', 'assistant', 'tienes 3 bots')],
  sending: sending,
  liveProgress: liveProgress,
  sendFailure: sendFailure,
  models: models,
  selectedModelId: selectedModelId,
);

void main() {
  late _MockBloc bloc;

  setUpAll(() {
    registerFallbackValue(const PaChatStarted());
  });

  setUp(() {
    bloc = _MockBloc();
  });

  Future<void> pump(WidgetTester tester, PaChatState state) async {
    whenListen(bloc, const Stream<PaChatState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: BlocProvider<PlatformAgentChatBloc>.value(
              value: bloc,
              child: const PlatformAgentPage(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('init perezoso: con estado ya cargado NO redispara Started', (
    tester,
  ) async {
    await pump(tester, _loaded());
    verifyNever(() => bloc.add(const PaChatStarted()));
  });

  testWidgets('Loaded pinta los mensajes y el composer', (tester) async {
    await pump(tester, _loaded());
    expect(find.text('tienes 3 bots'), findsOneWidget);
    expect(find.byKey(const Key('pa.composer.field')), findsOneWidget);
  });

  testWidgets('sending muestra el indicador en vivo', (tester) async {
    await pump(
      tester,
      _loaded(sending: true, liveProgress: 'Usando list_bots…'),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Usando list_bots…'), findsOneWidget);
  });

  testWidgets('Failed muestra copy + reintentar dispara Started', (
    tester,
  ) async {
    await pump(tester, const PaChatFailed(PaServerFailure()));
    expect(find.byKey(const Key('pa.retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pa.retry')));
    verify(() => bloc.add(const PaChatStarted())).called(1);
  });

  testWidgets('botón nuevo dispara NewConversationRequested', (tester) async {
    await pump(tester, _loaded());
    await tester.tap(find.byKey(const Key('pa.new_conversation')));
    verify(() => bloc.add(const PaChatNewConversationRequested())).called(1);
  });

  testWidgets('historial lista los hilos y selecciona uno', (tester) async {
    await pump(
      tester,
      _loaded(
        conversations: <PaConversation>[
          _conv(),
          _conv(id: 'c2', title: 'Ventas'),
        ],
      ),
    );
    await tester.tap(find.byKey(const Key('pa.history')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('pa.history.item.c2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pa.history.item.c2')));
    verify(() => bloc.add(const PaChatConversationSelected('c2'))).called(1);
  });

  testWidgets('enviar texto dispara MessageSent', (tester) async {
    await pump(tester, _loaded());
    await tester.enterText(
      find.byKey(const Key('pa.composer.field')),
      'cuántos bots',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('pa.composer.send')));
    verify(() => bloc.add(const PaChatMessageSent('cuántos bots'))).called(1);
  });

  testWidgets('init perezoso: en estado Loading dispara Started', (
    tester,
  ) async {
    await pump(tester, const PaChatLoading());
    verify(() => bloc.add(const PaChatStarted())).called(1);
  });

  testWidgets('selector de modelo: aparece con allowlist y elegir dispara', (
    tester,
  ) async {
    await pump(
      tester,
      _loaded(
        models: const <PaModelOption>[
          PaModelOption(id: 'gpt-5.5', label: 'ChatGPT 5.5'),
        ],
      ),
    );
    expect(find.byKey(const Key('pa.model.button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pa.model.button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pa.model.option.gpt-5.5')));
    await tester.pumpAndSettle();
    verify(() => bloc.add(const PaChatModelSelected('gpt-5.5'))).called(1);
  });

  testWidgets('selector de modelo: sin allowlist no se muestra', (
    tester,
  ) async {
    await pump(tester, _loaded());
    expect(find.byKey(const Key('pa.model.button')), findsNothing);
  });
}
