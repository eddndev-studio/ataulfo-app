import 'dart:async';
import 'dart:typed_data';

import 'package:ataulfo/core/audio/audio_recorder.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_conversation.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_message.dart';
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

/// Grabador de prueba con conteo de llamadas y resultado configurable.
class _FakeRecorder implements AudioRecorder {
  _FakeRecorder({this.supported = true, this.result});

  bool supported;
  bool permission = true;
  RecordedVoice? result;
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  Future<bool> isSupported() async => supported;
  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<void> start() async => startCalls++;
  @override
  Future<RecordedVoice?> stop() async {
    stopCalls++;
    return result;
  }

  @override
  Future<void> cancel() async => cancelCalls++;
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Stream<double> get amplitude => const Stream<double>.empty();
  @override
  Stream<Duration> get elapsed => Stream<Duration>.value(Duration.zero);
  @override
  Future<void> dispose() async {}
}

PaConversation _conv() => PaConversation(
  id: 'c1',
  title: 'Operación',
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

PaChatLoaded _loaded({bool recordingVoice = false}) => PaChatLoaded(
  conversations: <PaConversation>[_conv()],
  activeConversation: _conv(),
  messages: const <PaMessage>[],
  sending: false,
  recordingVoice: recordingVoice,
);

void main() {
  late _MockBloc bloc;

  setUpAll(() {
    registerFallbackValue(const PaChatStarted());
  });

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.activeDraft).thenReturn('');
    // La limpieza en dispose consulta isClosed antes de despachar.
    when(() => bloc.isClosed).thenReturn(false);
  });

  Future<void> pump(
    WidgetTester tester,
    PaChatState state,
    AudioRecorder recorder,
  ) async {
    whenListen(bloc, const Stream<PaChatState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: RepositoryProvider<AudioRecorder>.value(
              value: recorder,
              child: BlocProvider<PlatformAgentChatBloc>.value(
                value: bloc,
                child: wrapWithChatMedia(const PlatformAgentPage()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('con recorder soportado, el composer ofrece el micrófono', (
    tester,
  ) async {
    await pump(tester, _loaded(), _FakeRecorder());
    expect(find.byKey(const Key('pa.voice.mic')), findsOneWidget);
  });

  testWidgets('sin recorder soportado, no hay micrófono', (tester) async {
    await pump(tester, _loaded(), _FakeRecorder(supported: false));
    expect(find.byKey(const Key('pa.voice.mic')), findsNothing);
  });

  testWidgets('tap en el mic arranca la grabación y avisa al bloc', (
    tester,
  ) async {
    final rec = _FakeRecorder();
    await pump(tester, _loaded(), rec);
    // El mic entra al slot con el switcher del kit: dejarlo asentar antes
    // de tapear (a mitad de fade la opacity 0 no es hitteable).
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.byKey(const Key('pa.voice.mic')));
    await tester.pump();
    expect(rec.startCalls, 1);
    verify(() => bloc.add(const PaChatVoiceStarted())).called(1);
  });

  testWidgets('recordingVoice pinta la barra de grabación, no el campo', (
    tester,
  ) async {
    await pump(tester, _loaded(recordingVoice: true), _FakeRecorder());
    expect(find.byKey(const Key('voice.recording.bar')), findsOneWidget);
    expect(find.byKey(const Key('pa.composer.field')), findsNothing);
  });

  testWidgets('enviar la nota detiene el grabador y despacha VoiceSent', (
    tester,
  ) async {
    final rec = _FakeRecorder(
      result: RecordedVoice(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        duration: const Duration(seconds: 1),
      ),
    );
    await pump(tester, _loaded(recordingVoice: true), rec);
    await tester.tap(find.byKey(const Key('voice.send')));
    await tester.pump();
    expect(rec.stopCalls, 1);
    verify(() => bloc.add(any(that: isA<PaChatVoiceSent>()))).called(1);
  });

  testWidgets('descartar cancela el grabador y avisa al bloc', (tester) async {
    final rec = _FakeRecorder();
    await pump(tester, _loaded(recordingVoice: true), rec);
    await tester.tap(find.byKey(const Key('voice.cancel')));
    await tester.pump();
    expect(rec.cancelCalls, 1);
    verify(() => bloc.add(const PaChatVoiceCancelled())).called(1);
  });
}
