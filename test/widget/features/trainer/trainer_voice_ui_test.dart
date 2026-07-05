import 'dart:async';
import 'dart:typed_data';

import 'package:ataulfo/core/audio/audio_recorder.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_conversation.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/trainer_chat_bloc.dart';
import 'package:ataulfo/features/trainer/presentation/pages/trainer_chat_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/chat_media_providers.dart';

class _MockBloc extends MockBloc<TrainerChatEvent, TrainerChatState>
    implements TrainerChatBloc {}

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

TrainerConversation _conv() => TrainerConversation(
  id: 'c1',
  templateId: 't1',
  title: 'Entrenamiento',
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

TrainerChatLoaded _loaded({bool recordingVoice = false}) => TrainerChatLoaded(
  conversation: _conv(),
  conversations: <TrainerConversation>[_conv()],
  messages: const <TrainerMessage>[],
  sending: false,
  recordingVoice: recordingVoice,
);

void main() {
  late _MockBloc bloc;

  setUpAll(() {
    registerFallbackValue(const TrainerChatStarted());
  });

  setUp(() {
    bloc = _MockBloc();
    // La limpieza en dispose consulta isClosed antes de despachar.
    when(() => bloc.isClosed).thenReturn(false);
  });

  Future<void> pump(
    WidgetTester tester,
    TrainerChatState state,
    AudioRecorder recorder,
  ) async {
    whenListen(
      bloc,
      const Stream<TrainerChatState>.empty(),
      initialState: state,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: RepositoryProvider<AudioRecorder>.value(
              value: recorder,
              child: BlocProvider<TrainerChatBloc>.value(
                value: bloc,
                child: wrapWithChatMedia(
                  const TrainerChatPage(templateId: 't1'),
                ),
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
    expect(find.byKey(const Key('trainer.voice.mic')), findsOneWidget);
  });

  testWidgets('sin recorder soportado, no hay micrófono', (tester) async {
    await pump(tester, _loaded(), _FakeRecorder(supported: false));
    expect(find.byKey(const Key('trainer.voice.mic')), findsNothing);
  });

  testWidgets('tap en el mic arranca la grabación y avisa al bloc', (
    tester,
  ) async {
    final rec = _FakeRecorder();
    await pump(tester, _loaded(), rec);
    await tester.tap(find.byKey(const Key('trainer.voice.mic')));
    await tester.pump();
    expect(rec.startCalls, 1);
    verify(() => bloc.add(const TrainerChatVoiceStarted())).called(1);
  });

  testWidgets('recordingVoice pinta la barra de grabación, no el campo', (
    tester,
  ) async {
    await pump(tester, _loaded(recordingVoice: true), _FakeRecorder());
    expect(find.byKey(const Key('voice.recording.bar')), findsOneWidget);
    expect(find.byKey(const Key('trainer.composer.field')), findsNothing);
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
    verify(() => bloc.add(any(that: isA<TrainerChatVoiceSent>()))).called(1);
  });

  testWidgets('descartar cancela el grabador y avisa al bloc', (tester) async {
    final rec = _FakeRecorder();
    await pump(tester, _loaded(recordingVoice: true), rec);
    await tester.tap(find.byKey(const Key('voice.cancel')));
    await tester.pump();
    expect(rec.cancelCalls, 1);
    verify(() => bloc.add(const TrainerChatVoiceCancelled())).called(1);
  });
}
