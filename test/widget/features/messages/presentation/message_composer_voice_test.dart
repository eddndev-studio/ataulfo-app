import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/messages/data/cache/message_media_cache.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/domain/repositories/audio_recorder.dart';
import 'package:ataulfo/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:ataulfo/features/messages/presentation/widgets/message_composer.dart';
import 'package:ataulfo/features/quick_replies/presentation/bloc/quick_replies_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_message_media_cache.dart';

class _MockMessagesBloc extends MockBloc<MessagesEvent, MessagesState>
    implements MessagesBloc {}

class _MockQuickRepliesBloc
    extends MockBloc<QuickRepliesEvent, QuickRepliesState>
    implements QuickRepliesBloc {}

class _MockFilePicker extends Mock implements MediaFilePicker {}

class _MockMediaRepo extends Mock implements MediaRepository {}

/// Grabador de prueba con comportamiento configurable y conteo de llamadas.
class _FakeRecorder implements AudioRecorder {
  _FakeRecorder({this.supported = true, this.permission = true, this.result});

  bool supported;
  bool permission;
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
  Stream<double> get amplitude => const Stream<double>.empty();
  @override
  Stream<Duration> get elapsed => Stream<Duration>.value(Duration.zero);
  @override
  Future<void> dispose() async {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(
      const MessagesSendRequested(type: 'text', content: ''),
    );
  });

  late _MockMessagesBloc msgBloc;
  late _MockQuickRepliesBloc qrBloc;
  late _MockFilePicker picker;
  late _MockMediaRepo mediaRepo;
  late MessageMediaCache mediaCache;

  setUp(() {
    msgBloc = _MockMessagesBloc();
    qrBloc = _MockQuickRepliesBloc();
    picker = _MockFilePicker();
    mediaRepo = _MockMediaRepo();
    mediaCache = fakeMessageMediaCache();
    when(() => msgBloc.state).thenReturn(
      const MessagesLoaded(
        items: <Message>[],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    when(() => qrBloc.state).thenReturn(const QuickRepliesLoading());
  });

  Widget host(AudioRecorder recorder) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<MediaFilePicker>.value(value: picker),
        RepositoryProvider<MediaRepository>.value(value: mediaRepo),
        RepositoryProvider<MessageMediaCache>.value(value: mediaCache),
        RepositoryProvider<AudioRecorder>.value(value: recorder),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<MessagesBloc>.value(value: msgBloc),
          BlocProvider<QuickRepliesBloc>.value(value: qrBloc),
        ],
        child: const Scaffold(body: MessageComposer()),
      ),
    ),
  );

  testWidgets('sin soporte de grabación no muestra el botón de micrófono', (
    tester,
  ) async {
    await tester.pumpWidget(host(_FakeRecorder(supported: false)));
    await tester.pump(); // resuelve isSupported()
    expect(find.byKey(const Key('composer.mic')), findsNothing);
  });

  testWidgets('con soporte muestra el micrófono', (tester) async {
    await tester.pumpWidget(host(_FakeRecorder()));
    await tester.pump();
    expect(find.byKey(const Key('composer.mic')), findsOneWidget);
  });

  testWidgets('sin permiso de micrófono avisa y no entra a grabar', (
    tester,
  ) async {
    final recorder = _FakeRecorder(permission: false);
    await tester.pumpWidget(host(recorder));
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer.mic')));
    await tester.pump();
    expect(find.byKey(const Key('voice.recording.bar')), findsNothing);
    expect(recorder.startCalls, 0);
    expect(
      find.text('Permite el micrófono para grabar notas de voz'),
      findsOneWidget,
    );
  });

  testWidgets('tocar 🎤 inicia la grabación y muestra la barra', (
    tester,
  ) async {
    final recorder = _FakeRecorder();
    await tester.pumpWidget(host(recorder));
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer.mic')));
    await tester.pump(); // hasPermission + start
    expect(recorder.startCalls, 1);
    expect(find.byKey(const Key('voice.recording.bar')), findsOneWidget);
    expect(find.byKey(const Key('composer.input')), findsNothing);
  });

  testWidgets('doble toque del micrófono inicia la grabación una sola vez', (
    tester,
  ) async {
    final recorder = _FakeRecorder();
    await tester.pumpWidget(host(recorder));
    await tester.pump();
    // Dos toques antes de que start() resuelva: el guard debe bloquear el 2º.
    await tester.tap(find.byKey(const Key('composer.mic')));
    await tester.tap(find.byKey(const Key('composer.mic')));
    await tester.pump();
    expect(recorder.startCalls, 1);
  });

  testWidgets('enviar sube el clip y despacha type:ptt con el ref BARE', (
    tester,
  ) async {
    final recorder = _FakeRecorder(
      result: RecordedVoice(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        duration: const Duration(seconds: 2),
        waveform: const <int>[10, 20, 30],
      ),
    );
    when(
      () => mediaRepo.upload(
        bytes: any(named: 'bytes'),
        filename: any(named: 'filename'),
      ),
    ).thenAnswer(
      (_) async => const UploadedMedia(ref: 'ref-voz', previewUrl: null),
    );

    await tester.pumpWidget(host(recorder));
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer.mic')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('voice.send')));
    await tester.pumpAndSettle();

    expect(recorder.stopCalls, 1);
    verify(
      () => mediaRepo.upload(
        bytes: any(named: 'bytes'),
        filename: 'voice.ogg',
      ),
    ).called(1);
    verify(
      () => msgBloc.add(
        const MessagesSendRequested(
          type: 'ptt',
          content: '',
          mediaRef: 'ref-voz',
          waveform: <int>[10, 20, 30],
        ),
      ),
    ).called(1);
    // Sembró la caché con los bytes grabados bajo el ref definitivo: la
    // burbuja reconciliada reproduce desde disco sin round-trip de la firma.
    expect(
      await mediaCache.bytesFor('ref-voz', null),
      Uint8List.fromList(<int>[1, 2, 3]),
    );
    // Vuelve al composer tras enviar.
    expect(find.byKey(const Key('composer.input')), findsOneWidget);
  });

  testWidgets('una grabación vacía no se envía y avisa', (tester) async {
    final recorder = _FakeRecorder(result: null); // stop() devuelve null
    await tester.pumpWidget(host(recorder));
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer.mic')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('voice.send')));
    await tester.pumpAndSettle();

    verifyNever(
      () => mediaRepo.upload(
        bytes: any(named: 'bytes'),
        filename: any(named: 'filename'),
      ),
    );
    verifyNever(() => msgBloc.add(any()));
    expect(find.text('No se grabó audio'), findsOneWidget);
  });

  testWidgets('una nota muy corta no se envía y avisa', (tester) async {
    final recorder = _FakeRecorder(
      result: RecordedVoice(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        duration: const Duration(milliseconds: 300),
      ),
    );
    await tester.pumpWidget(host(recorder));
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer.mic')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('voice.send')));
    await tester.pumpAndSettle();

    verifyNever(
      () => mediaRepo.upload(
        bytes: any(named: 'bytes'),
        filename: any(named: 'filename'),
      ),
    );
    verifyNever(() => msgBloc.add(any()));
    expect(find.text('Nota de voz muy corta'), findsOneWidget);
  });

  testWidgets('cancelar descarta y vuelve al composer', (tester) async {
    final recorder = _FakeRecorder();
    await tester.pumpWidget(host(recorder));
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer.mic')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('voice.cancel')));
    await tester.pump();

    expect(recorder.cancelCalls, 1);
    expect(find.byKey(const Key('voice.recording.bar')), findsNothing);
    expect(find.byKey(const Key('composer.input')), findsOneWidget);
  });
}
