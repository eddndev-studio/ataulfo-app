import 'dart:typed_data';

import 'package:ataulfo/core/audio/audio_recorder.dart';
import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/data/repositories/noop_device_gallery.dart';
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

class _MockCamera extends Mock implements CameraCapture {}

void main() {
  late _MockMessagesBloc msgBloc;
  late _MockQuickRepliesBloc qrBloc;
  late _MockFilePicker picker;
  late _MockMediaRepo mediaRepo;
  late _MockCamera camera;

  setUp(() {
    msgBloc = _MockMessagesBloc();
    qrBloc = _MockQuickRepliesBloc();
    picker = _MockFilePicker();
    mediaRepo = _MockMediaRepo();
    camera = _MockCamera();
    when(() => msgBloc.state).thenReturn(
      const MessagesLoaded(
        items: <Message>[],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    when(() => qrBloc.state).thenReturn(const QuickRepliesLoading());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<MediaFilePicker>.value(value: picker),
        RepositoryProvider<MediaRepository>.value(value: mediaRepo),
        RepositoryProvider<CameraCapture>.value(value: camera),
        RepositoryProvider<DeviceGalleryPort>.value(
          value: const NoopDeviceGallery(),
        ),
        RepositoryProvider<AudioRecorder>.value(
          value: const NoopAudioRecorder(),
        ),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<MessagesBloc>.value(value: msgBloc),
          BlocProvider<QuickRepliesBloc>.value(value: qrBloc),
          BlocProvider<ReplyDraftCubit>(create: (_) => ReplyDraftCubit()),
          BlocProvider<AttachPanelCubit>(create: (_) => AttachPanelCubit()),
        ],
        child: const Scaffold(body: AttachThreadHarness()),
      ),
    ),
  );

  Future<void> openAttachMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('composer.attach')));
    await tester.pumpAndSettle();
  }

  testWidgets('sin soporte de cámara el panel NO ofrece Cámara', (
    tester,
  ) async {
    when(camera.isSupported).thenAnswer((_) async => false);

    await tester.pumpWidget(host());
    await openAttachMenu(tester);

    expect(find.byKey(const Key('attach_panel.fixed')), findsOneWidget);
    expect(find.byKey(const Key('attach_menu.document')), findsOneWidget);
    expect(find.byKey(const Key('attach_menu.camera')), findsNothing);
  });

  testWidgets(
    'con soporte, tocar Cámara cambia a la vista de cámara (sin ruta)',
    (tester) async {
      when(camera.isSupported).thenAnswer((_) async => true);

      await tester.pumpWidget(host());
      await openAttachMenu(tester);

      expect(find.byKey(const Key('attach_menu.camera')), findsOneWidget);
      await tester.tap(find.byKey(const Key('attach_menu.camera')));
      await tester.pumpAndSettle();

      // El mismo panel ahora muestra Foto/Video; la fila de destinos se fue.
      expect(find.byKey(const Key('attach_menu.document')), findsNothing);
      expect(find.byKey(const Key('attach_menu.camera.photo')), findsOneWidget);
      expect(find.byKey(const Key('attach_menu.camera.video')), findsOneWidget);
    },
  );

  testWidgets('Tomar foto invoca takePhoto y agrega el adjunto a la bandeja', (
    tester,
  ) async {
    when(camera.isSupported).thenAnswer((_) async => true);
    when(camera.takePhoto).thenAnswer(
      (_) async =>
          PickedMedia(bytes: Uint8List.fromList(<int>[1]), filename: 'f.jpg'),
    );

    await tester.pumpWidget(host());
    await openAttachMenu(tester);
    await tester.tap(find.byKey(const Key('attach_menu.camera')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach_menu.camera.photo')));
    await tester.pumpAndSettle();

    verify(camera.takePhoto).called(1);
    verifyNever(camera.takeVideo);
    // Ambos sheets cerrados; la captura entró a la bandeja como bytes locales.
    expect(find.byKey(const Key('attach_menu.camera.photo')), findsNothing);
    expect(find.byKey(const Key('composer.attachment_tray')), findsOneWidget);
    expect(find.text('1 archivo'), findsOneWidget);
  });

  testWidgets('Grabar video invoca takeVideo y agrega el adjunto', (
    tester,
  ) async {
    when(camera.isSupported).thenAnswer((_) async => true);
    when(camera.takeVideo).thenAnswer(
      (_) async =>
          PickedMedia(bytes: Uint8List.fromList(<int>[2]), filename: 'v.mp4'),
    );

    await tester.pumpWidget(host());
    await openAttachMenu(tester);
    await tester.tap(find.byKey(const Key('attach_menu.camera')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach_menu.camera.video')));
    await tester.pumpAndSettle();

    verify(camera.takeVideo).called(1);
    expect(find.byKey(const Key('composer.attachment_tray')), findsOneWidget);
    expect(find.text('v.mp4'), findsOneWidget);
  });

  testWidgets(
    'un fallo de la cámara avisa con SnackBar y no agrega nada a la bandeja',
    (tester) async {
      when(camera.isSupported).thenAnswer((_) async => true);
      when(camera.takePhoto).thenThrow(const CameraCaptureFailure());

      await tester.pumpWidget(host());
      await openAttachMenu(tester);
      await tester.tap(find.byKey(const Key('attach_menu.camera')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attach_menu.camera.photo')));
      await tester.pumpAndSettle();

      expect(find.text('No pudimos abrir la cámara'), findsOneWidget);
      expect(find.byKey(const Key('composer.attachment_tray')), findsNothing);
    },
  );

  testWidgets(
    'un fallo de la cámara de video avisa con SnackBar sin agregar nada',
    (tester) async {
      when(camera.isSupported).thenAnswer((_) async => true);
      when(camera.takeVideo).thenThrow(const CameraCaptureFailure());

      await tester.pumpWidget(host());
      await openAttachMenu(tester);
      await tester.tap(find.byKey(const Key('attach_menu.camera')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attach_menu.camera.video')));
      await tester.pumpAndSettle();

      expect(find.text('No pudimos abrir la cámara'), findsOneWidget);
      expect(find.byKey(const Key('composer.attachment_tray')), findsNothing);
    },
  );

  testWidgets('cancelar la captura (null) no agrega nada a la bandeja', (
    tester,
  ) async {
    when(camera.isSupported).thenAnswer((_) async => true);
    when(camera.takePhoto).thenAnswer((_) async => null);

    await tester.pumpWidget(host());
    await openAttachMenu(tester);
    await tester.tap(find.byKey(const Key('attach_menu.camera')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach_menu.camera.photo')));
    await tester.pumpAndSettle();

    verify(camera.takePhoto).called(1);
    expect(find.byKey(const Key('composer.attachment_tray')), findsNothing);
  });
}
