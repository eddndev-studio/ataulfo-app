import 'dart:async';

import 'package:ataulfo/core/audio/audio_recorder.dart';
import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/repositories/camera_capture.dart';
import 'package:ataulfo/features/media/domain/repositories/device_gallery_port.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/messages/data/media/noop_audio_recorder.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:ataulfo/features/messages/presentation/bloc/reply_draft_cubit.dart';
import 'package:ataulfo/features/messages/presentation/widgets/message_composer.dart';
import 'package:ataulfo/features/quick_replies/presentation/bloc/quick_replies_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

  setUp(() {
    msgBloc = _MockMessagesBloc();
    qrBloc = _MockQuickRepliesBloc();
    picker = _MockFilePicker();
    mediaRepo = _MockMediaRepo();
    camera = _MockCameraCapture();
    gallery = _MockDeviceGallery();
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
        ],
        child: const Scaffold(body: MessageComposer()),
      ),
    ),
  );

  testWidgets(
    'tocar el clip suelta el foco del campo ANTES de resolver soporte de '
    'cámara/carrete (la señal de cerrar el teclado no espera a los checks '
    'async ni a que el sheet abra)',
    (tester) async {
      // Soporte de cámara/carrete PENDIENTE: emula el round-trip real a la
      // plataforma (en Android el chequeo del carrete puede incluso pedir
      // permiso). Mientras no resuelva, el sheet NO puede abrir — si el foco
      // sólo se soltara como efecto colateral del sheet, seguiría puesto.
      final cameraSupport = Completer<bool>();
      final gallerySupport = Completer<bool>();
      when(camera.isSupported).thenAnswer((_) => cameraSupport.future);
      when(gallery.isSupported).thenAnswer((_) => gallerySupport.future);

      await tester.pumpWidget(host());

      // El operador está escribiendo: el campo tiene el foco (teclado abierto).
      await tester.tap(find.byKey(const Key('composer.input')));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const Key('composer.input')),
      );
      expect(
        field.focusNode!.hasFocus,
        isTrue,
        reason: 'setup: campo enfocado',
      );

      await tester.tap(find.byKey(const Key('composer.attach')));
      await tester.pump();

      // El sheet aún NO existe (soporte sin resolver)…
      expect(find.byKey(const Key('attach_menu_sheet')), findsNothing);
      // …pero el foco ya se soltó: el teclado recibió la orden de cerrarse en
      // el instante del tap, no cuando el sheet finalmente abre.
      expect(field.focusNode!.hasFocus, isFalse);

      // Al resolver el soporte, el flujo sigue: el menú abre con normalidad.
      cameraSupport.complete(false);
      gallerySupport.complete(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attach_menu_sheet')), findsOneWidget);
    },
  );
}
