import 'package:ataulfo/core/audio/audio_recorder.dart';
import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/data/repositories/noop_camera_capture.dart';
import 'package:ataulfo/features/media/data/repositories/noop_device_gallery.dart';
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

/// Reacomodo del Scaffold del hilo ante el teclado virtual, simulado a nivel
/// de la vista (`tester.view.viewInsets`, en píxeles FÍSICOS): el mismo canal
/// por el que Android reporta el teclado real. Documenta que el Scaffold
/// (resizeToAvoidBottomInset default) SÍ baja el composer cuando el inset
/// vuelve a 0 — incluso con el sheet modal de adjuntar abierto encima — y que
/// por tanto el hueco visual del bug era sólo el unfocus tardío, no un
/// problema de reflow.
void main() {
  late _MockMessagesBloc msgBloc;
  late _MockQuickRepliesBloc qrBloc;

  setUp(() {
    msgBloc = _MockMessagesBloc();
    qrBloc = _MockQuickRepliesBloc();
    when(() => msgBloc.state).thenReturn(
      const MessagesLoaded(
        items: <Message>[],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    when(() => qrBloc.state).thenReturn(const QuickRepliesLoading());
  });

  // Como el hilo real: Scaffold (resizeToAvoidBottomInset default true) con la
  // lista expandida arriba y el composer al fondo.
  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<MediaFilePicker>.value(value: _MockFilePicker()),
        RepositoryProvider<MediaRepository>.value(value: _MockMediaRepo()),
        RepositoryProvider<CameraCapture>.value(
          value: const NoopCameraCapture(),
        ),
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
        ],
        child: const Scaffold(
          body: Column(
            children: <Widget>[
              Expanded(child: SizedBox()),
              MessageComposer(),
            ],
          ),
        ),
      ),
    ),
  );

  // Vista default del harness: 800x600 lógicos @ dpr 3.0. El inset del
  // teclado se inyecta en píxeles físicos (300 lógicos = 900 físicos).
  const double keyboardLogical = 300;
  const double screenHeight = 600;

  Finder composer() => find.byType(MessageComposer);

  testWidgets(
    'el Scaffold empuja el composer sobre el teclado y lo baja al cerrarse '
    '(sin sheet encima)',
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pumpWidget(host());

      expect(
        tester.getRect(composer()).bottom,
        moreOrLessEquals(screenHeight - keyboardLogical),
        reason: 'con teclado abierto el composer vive sobre el inset',
      );

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      expect(
        tester.getRect(composer()).bottom,
        moreOrLessEquals(screenHeight),
        reason: 'al cerrarse el teclado el composer baja al fondo',
      );
    },
  );

  testWidgets(
    'con el sheet de adjuntar abierto ENCIMA, el Scaffold de atrás sigue '
    'reaccionando al cierre del teclado (el composer baja, no queda congelado)',
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pumpWidget(host());

      expect(
        tester.getRect(composer()).bottom,
        moreOrLessEquals(screenHeight - keyboardLogical),
      );

      // Abre el menú de adjuntar por el flujo real (el clip del composer).
      await tester.tap(
        find.byKey(const Key('composer.attach')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attach_menu_sheet')), findsOneWidget);

      // El teclado se cierra con el sheet aún activo (exactamente la secuencia
      // del bug reportado).
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('attach_menu_sheet')), findsOneWidget);
      expect(
        tester.getRect(composer()).bottom,
        moreOrLessEquals(screenHeight),
        reason:
            'la ruta base detrás del sheet modal reconstruye con el nuevo '
            'MediaQuery: el composer baja aunque el sheet siga abierto',
      );
    },
  );
}
