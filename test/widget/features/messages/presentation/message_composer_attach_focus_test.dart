import 'dart:async';

import 'package:ataulfo/core/audio/audio_recorder.dart';
import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/repositories/camera_capture.dart';
import 'package:ataulfo/features/media/domain/repositories/device_gallery_port.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/messages/data/media/noop_audio_recorder.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/presentation/bloc/attach_panel_cubit.dart';
import 'package:ataulfo/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:ataulfo/features/messages/presentation/bloc/reply_draft_cubit.dart';
import 'package:ataulfo/features/quick_replies/presentation/bloc/quick_replies_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/attach_thread_harness.dart';

class _MockMessagesBloc extends MockBloc<MessagesEvent, MessagesState>
    implements MessagesBloc {}

class _MockQuickRepliesBloc
    extends MockBloc<QuickRepliesEvent, QuickRepliesState>
    implements QuickRepliesBloc {}

class _MockFilePicker extends Mock implements MediaFilePicker {}

class _MockMediaRepo extends Mock implements MediaRepository {}

class _MockCameraCapture extends Mock implements CameraCapture {}

class _MockDeviceGallery extends Mock implements DeviceGalleryPort {}

void main() {
  late _MockMessagesBloc msgBloc;
  late _MockQuickRepliesBloc qrBloc;
  late _MockFilePicker picker;
  late _MockMediaRepo mediaRepo;
  late _MockCameraCapture camera;
  late _MockDeviceGallery gallery;
  late AttachPanelCubit panelCubit;

  setUp(() {
    msgBloc = _MockMessagesBloc();
    qrBloc = _MockQuickRepliesBloc();
    picker = _MockFilePicker();
    mediaRepo = _MockMediaRepo();
    camera = _MockCameraCapture();
    gallery = _MockDeviceGallery();
    panelCubit = AttachPanelCubit();
    when(() => msgBloc.state).thenReturn(
      const MessagesLoaded(
        items: <Message>[],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    when(() => qrBloc.state).thenReturn(const QuickRepliesLoading());
  });

  tearDown(() => panelCubit.close());

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<MediaFilePicker>.value(value: picker),
        RepositoryProvider<MediaRepository>.value(value: mediaRepo),
        RepositoryProvider<CameraCapture>.value(value: camera),
        RepositoryProvider<DeviceGalleryPort>.value(value: gallery),
        RepositoryProvider<AudioRecorder>.value(
          value: const NoopAudioRecorder(),
        ),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<MessagesBloc>.value(value: msgBloc),
          BlocProvider<QuickRepliesBloc>.value(value: qrBloc),
          BlocProvider<ReplyDraftCubit>(create: (_) => ReplyDraftCubit()),
          BlocProvider<AttachPanelCubit>.value(value: panelCubit),
        ],
        child: const Scaffold(body: AttachThreadHarness()),
      ),
    ),
  );

  bool fieldFocused(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const Key('composer.input')))
      .focusNode!
      .hasFocus;

  testWidgets(
    'tocar el clip suelta el foco del campo ANTES de resolver el soporte '
    'de cámara/carrete (intercambio teclado→panel, sin esperar los checks '
    'async ni a que el panel abra)',
    (tester) async {
      // Soporte de cámara/carrete PENDIENTE: emula el round-trip real a la
      // plataforma. Mientras no resuelva, el panel NO puede abrir — si el foco
      // sólo se soltara como efecto colateral del panel, seguiría puesto.
      final cameraSupport = Completer<bool>();
      final gallerySupport = Completer<bool>();
      when(camera.isSupported).thenAnswer((_) => cameraSupport.future);
      when(gallery.isSupported).thenAnswer((_) => gallerySupport.future);

      await tester.pumpWidget(host());

      // El operador está escribiendo: el campo tiene el foco (teclado abierto).
      await tester.tap(find.byKey(const Key('composer.input')));
      await tester.pump();
      expect(fieldFocused(tester), isTrue, reason: 'setup: campo enfocado');

      await tester.tap(find.byKey(const Key('composer.attach')));
      await tester.pump();

      // El panel aún NO está abierto (soporte sin resolver)…
      expect(panelCubit.isOpen, isFalse);
      // …pero el foco ya se soltó: el teclado recibió la orden de cerrarse en
      // el instante del tap, no cuando el panel finalmente abre.
      expect(fieldFocused(tester), isFalse);

      // Al resolver el soporte, el panel abre con normalidad.
      cameraSupport.complete(false);
      gallerySupport.complete(false);
      await tester.pumpAndSettle();
      expect(panelCubit.isOpen, isTrue);
      expect(find.byKey(const Key('attach_menu.document')), findsOneWidget);
    },
  );

  testWidgets('enfocar el campo cierra el panel (nunca conviven)', (
    tester,
  ) async {
    when(camera.isSupported).thenAnswer((_) async => false);
    when(gallery.isSupported).thenAnswer((_) async => false);

    await tester.pumpWidget(host());

    // Abre el panel por el flujo real.
    await tester.tap(find.byKey(const Key('composer.attach')));
    await tester.pumpAndSettle();
    expect(panelCubit.isOpen, isTrue);

    // Enfocar el campo (el operador vuelve a escribir) cierra el panel.
    await tester.tap(find.byKey(const Key('composer.input')));
    await tester.pumpAndSettle();
    expect(panelCubit.isOpen, isFalse);
    expect(find.byKey(const Key('attach_menu.document')), findsNothing);
  });

  testWidgets('tocar el clip con el panel abierto lo cierra (toggle)', (
    tester,
  ) async {
    when(camera.isSupported).thenAnswer((_) async => false);
    when(gallery.isSupported).thenAnswer((_) async => false);

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('composer.attach')));
    await tester.pumpAndSettle();
    expect(panelCubit.isOpen, isTrue);

    await tester.tap(find.byKey(const Key('composer.attach')));
    await tester.pumpAndSettle();
    expect(panelCubit.isOpen, isFalse);
  });

  testWidgets(
    're-enfocar el campo DURANTE los checks de soporte impide que el panel '
    'abra al resolverse (I5: nunca conviven teclado y panel)',
    (tester) async {
      // Soporte PENDIENTE: `open()` llega tras dos awaits de isSupported().
      final cameraSupport = Completer<bool>();
      final gallerySupport = Completer<bool>();
      when(camera.isSupported).thenAnswer((_) => cameraSupport.future);
      when(gallery.isSupported).thenAnswer((_) => gallerySupport.future);

      await tester.pumpWidget(host());

      // Tocar el clip suelta el foco y arranca los checks (aún sin resolver).
      await tester.tap(find.byKey(const Key('composer.attach')));
      await tester.pump();
      expect(fieldFocused(tester), isFalse);
      expect(panelCubit.isOpen, isFalse);

      // El operador vuelve a tocar el campo DENTRO de esa ventana: reabre el
      // teclado. Cuando el soporte resuelva, abrir el panel los haría convivir.
      await tester.tap(find.byKey(const Key('composer.input')));
      await tester.pump();
      expect(fieldFocused(tester), isTrue);

      cameraSupport.complete(true);
      gallerySupport.complete(true);
      await tester.pumpAndSettle();

      expect(
        panelCubit.isOpen,
        isFalse,
        reason: 'con el campo enfocado, el panel no debe abrir',
      );
      expect(fieldFocused(tester), isTrue);
    },
  );
}
