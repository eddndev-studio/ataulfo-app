import 'dart:async';
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
import 'package:flutter/semantics.dart';
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
/// `startGate`, si se da, retiene `start()` hasta completarse (para ejercer la
/// carrera soltar-antes-de-grabar).
class _FakeRecorder implements AudioRecorder {
  _FakeRecorder({
    this.supported = true,
    this.permission = true,
    this.result,
    this.startGate,
  });

  bool supported;
  bool permission;
  RecordedVoice? result;
  Completer<void>? startGate;
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  Future<bool> isSupported() async => supported;
  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<void> start() async {
    startCalls++;
    if (startGate != null) await startGate!.future;
  }

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
  late DateTime fakeNow;

  setUp(() {
    msgBloc = _MockMessagesBloc();
    qrBloc = _MockQuickRepliesBloc();
    picker = _MockFilePicker();
    mediaRepo = _MockMediaRepo();
    mediaCache = fakeMessageMediaCache();
    fakeNow = DateTime(2026, 1, 1, 12);
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
        child: Scaffold(body: MessageComposer(now: () => fakeNow)),
      ),
    ),
  );

  /// Mantiene el dedo sobre el micrófono y deja que `start()` resuelva. Devuelve
  /// el gesto vivo para deslizar/soltar.
  Future<TestGesture> pressMic(WidgetTester tester) async {
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('composer.mic'))),
    );
    await tester.pump(); // hasPermission + start
    return g;
  }

  void stubUpload() {
    when(
      () => mediaRepo.upload(
        bytes: any(named: 'bytes'),
        filename: any(named: 'filename'),
      ),
    ).thenAnswer(
      (_) async => const UploadedMedia(ref: 'ref-voz', previewUrl: null),
    );
  }

  RecordedVoice voice({Duration duration = const Duration(seconds: 2)}) =>
      RecordedVoice(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        duration: duration,
        waveform: const <int>[10, 20, 30],
      );

  testWidgets('sin soporte de grabación no muestra el botón de micrófono', (
    tester,
  ) async {
    await tester.pumpWidget(host(_FakeRecorder(supported: false)));
    await tester.pump(); // resuelve isSupported()
    expect(find.byKey(const Key('composer.mic')), findsNothing);
  });

  testWidgets('con soporte muestra el micrófono en el slot final', (
    tester,
  ) async {
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
    final g = await pressMic(tester);
    expect(find.byKey(const Key('voice.hold.bar')), findsNothing);
    expect(recorder.startCalls, 0);
    expect(
      find.text('Permite el micrófono para grabar notas de voz'),
      findsOneWidget,
    );
    await g.up();
  });

  testWidgets('MANTENER el micrófono inicia la grabación y muestra la barra', (
    tester,
  ) async {
    final recorder = _FakeRecorder();
    await tester.pumpWidget(host(recorder));
    await tester.pump();
    final g = await pressMic(tester);
    expect(recorder.startCalls, 1);
    expect(find.byKey(const Key('voice.hold.bar')), findsOneWidget);
    expect(find.byKey(const Key('composer.input')), findsNothing);
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('doble pulsación inicia la grabación una sola vez', (
    tester,
  ) async {
    final recorder = _FakeRecorder();
    await tester.pumpWidget(host(recorder));
    await tester.pump();
    // Dos punteros sobre el micrófono antes de que start() resuelva: el guard
    // bloquea el segundo.
    final center = tester.getCenter(find.byKey(const Key('composer.mic')));
    final g1 = await tester.startGesture(center);
    final g2 = await tester.startGesture(center);
    await tester.pump();
    expect(recorder.startCalls, 1);
    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();
  });

  testWidgets('MANTENER y soltar sube el clip y despacha type:ptt', (
    tester,
  ) async {
    final recorder = _FakeRecorder(result: voice());
    stubUpload();

    await tester.pumpWidget(host(recorder));
    await tester.pump();
    final g = await pressMic(tester);
    fakeNow = fakeNow.add(const Duration(seconds: 1)); // mantuvo > umbral
    await g.up();
    await tester.pumpAndSettle();

    expect(recorder.stopCalls, 1);
    verify(
      () => mediaRepo.upload(bytes: any(named: 'bytes'), filename: 'voice.ogg'),
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
    expect(
      await mediaCache.bytesFor('ref-voz', null),
      Uint8List.fromList(<int>[1, 2, 3]),
    );
    expect(find.byKey(const Key('composer.input')), findsOneWidget);
  });

  testWidgets('un toque corto NO graba: pista "mantén para grabar", sin subir', (
    tester,
  ) async {
    final recorder = _FakeRecorder(result: voice());
    await tester.pumpWidget(host(recorder));
    await tester.pump();
    final g = await pressMic(tester);
    await g.up(); // sin avanzar el reloj: mantuvo < umbral
    await tester.pumpAndSettle();

    expect(recorder.cancelCalls, 1);
    expect(recorder.stopCalls, 0);
    verifyNever(
      () => mediaRepo.upload(
        bytes: any(named: 'bytes'),
        filename: any(named: 'filename'),
      ),
    );
    verifyNever(() => msgBloc.add(any()));
    expect(find.text('Mantén para grabar una nota de voz'), findsOneWidget);
    expect(find.text('No se grabó audio'), findsNothing);
  });

  testWidgets('deslizar a la IZQUIERDA y soltar descarta (sin subir)', (
    tester,
  ) async {
    final recorder = _FakeRecorder(result: voice());
    await tester.pumpWidget(host(recorder));
    await tester.pump();
    final g = await pressMic(tester);
    await g.moveBy(const Offset(-140, 0));
    await tester.pump();
    expect(find.byKey(const Key('voice.cancelArmed')), findsOneWidget);
    fakeNow = fakeNow.add(const Duration(seconds: 1));
    await g.up();
    await tester.pumpAndSettle();

    expect(recorder.cancelCalls, 1);
    verifyNever(
      () => mediaRepo.upload(
        bytes: any(named: 'bytes'),
        filename: any(named: 'filename'),
      ),
    );
    expect(find.byKey(const Key('composer.input')), findsOneWidget);
  });

  testWidgets('deslizar ARRIBA bloquea: barra con botones, soltar NO envía', (
    tester,
  ) async {
    final recorder = _FakeRecorder(result: voice());
    await tester.pumpWidget(host(recorder));
    await tester.pump();
    final g = await pressMic(tester);
    await g.moveBy(const Offset(0, -120)); // cruza el umbral de bloqueo
    await tester.pump();

    // Estado bloqueado: la barra con enviar/descartar reemplaza a la de mantener.
    expect(find.byKey(const Key('voice.recording.bar')), findsOneWidget);
    expect(find.byKey(const Key('voice.send')), findsOneWidget);
    expect(find.byKey(const Key('voice.cancel')), findsOneWidget);

    // Soltar el dedo en bloqueado NO envía ni rompe (Listener estable: el
    // micrófono desmontado no deja un objeto-render colgado en la ruta).
    await g.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('voice.recording.bar')), findsOneWidget);
    verifyNever(() => msgBloc.add(any()));
  });

  testWidgets('bloqueado: tocar enviar sube y despacha', (tester) async {
    final recorder = _FakeRecorder(result: voice());
    stubUpload();
    await tester.pumpWidget(host(recorder));
    await tester.pump();
    final g = await pressMic(tester);
    await g.moveBy(const Offset(0, -120));
    await tester.pump();
    await g.up(); // bloqueado: manos libres
    await tester.pump();

    await tester.tap(find.byKey(const Key('voice.send')));
    await tester.pumpAndSettle();

    expect(recorder.stopCalls, 1);
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
  });

  testWidgets(
    'carrera soltar-antes-de-grabar: no muestra "No se grabó audio"',
    (tester) async {
      final gate = Completer<void>();
      final recorder = _FakeRecorder(result: voice(), startGate: gate);
      await tester.pumpWidget(host(recorder));
      await tester.pump();

      // Dedo abajo (start() queda retenido por el gate) y se suelta YA.
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('composer.mic'))),
      );
      await tester.pump(); // hasPermission resuelve; start() espera el gate
      await g.up(); // suelta antes de que la grabación esté lista
      await tester.pump();
      gate.complete(); // ahora sí arranca → aplica el release pendiente
      await tester.pumpAndSettle();

      // Fue un toque corto: descarta con la pista, nunca "No se grabó audio".
      expect(find.text('No se grabó audio'), findsNothing);
      verifyNever(
        () => mediaRepo.upload(
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      );
      expect(find.byKey(const Key('composer.input')), findsOneWidget);
    },
  );

  testWidgets(
    'accesibilidad: el micrófono expone una acción tap (activable por lector)',
    (tester) async {
      // El gesto de mantener no es operable por lector de pantalla; sin una
      // acción semántica `tap` AT no podría grabar. (Antes era un Container
      // pasivo sin acción.)
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(_FakeRecorder()));
      await tester.pump();

      final data = tester
          .getSemantics(find.byKey(const Key('composer.mic')))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, contains('Grabar nota de voz'));
      handle.dispose();
    },
  );

  testWidgets('soltar manteniendo muestra "Enviando…" durante la subida', (
    tester,
  ) async {
    final uploadGate = Completer<UploadedMedia>();
    final recorder = _FakeRecorder(result: voice());
    when(
      () => mediaRepo.upload(
        bytes: any(named: 'bytes'),
        filename: any(named: 'filename'),
      ),
    ).thenAnswer((_) => uploadGate.future);

    await tester.pumpWidget(host(recorder));
    await tester.pump();
    final g = await pressMic(tester);
    fakeNow = fakeNow.add(const Duration(seconds: 1));
    await g.up();
    await tester.pump(); // stop() + _sendingVoice=true
    await tester.pump(const Duration(milliseconds: 10));

    // La barra de mantener muestra el spinner de envío, no "desliza para
    // cancelar", mientras la subida está en vuelo.
    expect(find.byKey(const Key('voice.sending')), findsOneWidget);
    expect(find.byKey(const Key('voice.cancelArmed')), findsNothing);

    uploadGate.complete(const UploadedMedia(ref: 'ref-voz', previewUrl: null));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composer.input')), findsOneWidget);
  });
}
