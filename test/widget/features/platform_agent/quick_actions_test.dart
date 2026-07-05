import 'package:ataulfo/features/platform_agent/domain/entities/pa_conversation.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_message.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_models.dart';
import 'package:ataulfo/features/platform_agent/presentation/bloc/platform_agent_chat_bloc.dart';
import 'package:ataulfo/features/platform_agent/presentation/pages/platform_agent_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/chat_media_providers.dart';

class _MockBloc extends MockBloc<PaChatEvent, PaChatState>
    implements PlatformAgentChatBloc {}

PaConversation _conv() => PaConversation(
  id: 'c1',
  title: 'Operación',
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

PaChatLoaded _empty() => PaChatLoaded(
  conversations: <PaConversation>[_conv()],
  activeConversation: _conv(),
  messages: const <PaMessage>[],
  sending: false,
  models: const <PaModelOption>[],
);

void main() {
  late _MockBloc bloc;

  setUpAll(() => registerFallbackValue(const PaChatStarted()));
  setUp(() {
    bloc = _MockBloc();
    // La página lee el borrador vivo del bloc al montar el composer.
    when(() => bloc.activeDraft).thenReturn('');
  });

  Future<void> pump(WidgetTester tester) async {
    whenListen(bloc, const Stream<PaChatState>.empty(), initialState: _empty());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: BlocProvider<PlatformAgentChatBloc>.value(
              value: bloc,
              child: wrapWithChatMedia(const PlatformAgentPage()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('en vacío hay chips de acción rápida que prefijan el composer', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('pa.quick_action.pause')), findsOneWidget);

    await tester.tap(find.byKey(const Key('pa.quick_action.pause')));
    await tester.pump();

    // El composer queda prefijado con el arranque editable (label distinto del
    // texto, para no confundir el chip con el campo).
    expect(find.text('Pausa el bot '), findsOneWidget);
  });
}
