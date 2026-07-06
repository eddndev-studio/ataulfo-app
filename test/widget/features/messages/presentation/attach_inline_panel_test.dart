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

/// Cuenta los push de ruta: el panel de adjuntar NO debe abrir rutas (ni el
/// menú ni la sub-vista de cámara).
class _CountingObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

void main() {
  late _MockMessagesBloc msgBloc;
  late _MockQuickRepliesBloc qrBloc;
  late _MockCamera camera;
  late AttachPanelCubit panelCubit;
  late _CountingObserver observer;

  setUp(() {
    msgBloc = _MockMessagesBloc();
    qrBloc = _MockQuickRepliesBloc();
    camera = _MockCamera();
    panelCubit = AttachPanelCubit();
    observer = _CountingObserver();
    when(() => msgBloc.state).thenReturn(
      const MessagesLoaded(
        items: <Message>[],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    when(() => qrBloc.state).thenReturn(const QuickRepliesLoading());
    when(camera.isSupported).thenAnswer((_) async => true);
  });

  tearDown(() => panelCubit.close());

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    navigatorObservers: <NavigatorObserver>[observer],
    home: MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<MediaFilePicker>.value(value: _MockFilePicker()),
        RepositoryProvider<MediaRepository>.value(value: _MockMediaRepo()),
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
          BlocProvider<AttachPanelCubit>.value(value: panelCubit),
        ],
        child: const Scaffold(body: AttachThreadHarness()),
      ),
    ),
  );

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('composer.attach')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'panel abierto: el composer sigue visible y su campo queda por ENCIMA del '
    'panel (no lo tapa) — I1',
    (tester) async {
      await tester.pumpWidget(host());
      await openPanel(tester);

      // El composer y sus controles siguen presentes y usables.
      expect(find.byKey(const Key('app_chat_composer.bar')), findsOneWidget);
      expect(find.byKey(const Key('composer.input')), findsOneWidget);
      expect(find.byKey(const Key('composer.attach')), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const Key('composer.input')),
      );
      expect(field.enabled, isTrue);

      // El campo del composer cae por encima del panel (no queda cubierto).
      final fieldRect = tester.getRect(find.byKey(const Key('composer.input')));
      final panelRect = tester.getRect(
        find.byKey(const Key('attach_panel.fixed')),
      );
      expect(fieldRect.bottom, lessThanOrEqualTo(panelRect.top + 1));
    },
  );

  testWidgets(
    'tocar Cámara cambia de vista SIN abrir una ruta (I4): Navigator no recibe '
    'push más allá de la ruta inicial',
    (tester) async {
      await tester.pumpWidget(host());
      final pushesAfterStart = observer.pushes;

      await openPanel(tester);
      expect(find.byKey(const Key('attach_menu.camera')), findsOneWidget);
      await tester.tap(find.byKey(const Key('attach_menu.camera')));
      await tester.pumpAndSettle();

      // Cambió a la vista de cámara (mismo panel), sin push de ruta.
      expect(find.byKey(const Key('attach_menu.camera.photo')), findsOneWidget);
      expect(observer.pushes, pushesAfterStart);
    },
  );

  testWidgets(
    'el back del sistema en la sub-vista de Cámara vuelve a destinos (un '
    'nivel), y desde destinos recién cierra el panel',
    (tester) async {
      await tester.pumpWidget(host());
      await openPanel(tester);
      await tester.tap(find.byKey(const Key('attach_menu.camera')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attach_menu.camera.photo')), findsOneWidget);

      // Primer back: un nivel atrás (destinos), el panel sigue abierto.
      final first = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(first, isTrue);
      expect(panelCubit.isOpen, isTrue);
      expect(panelCubit.state?.view, AttachPanelView.destinations);
      expect(find.byKey(const Key('attach_menu.document')), findsOneWidget);

      // Segundo back: ahora sí cierra el panel (sin navegar).
      final second = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(second, isTrue);
      expect(panelCubit.isOpen, isFalse);
      expect(find.byKey(const Key('composer.input')), findsOneWidget);
    },
  );

  testWidgets(
    'el back del sistema con panel abierto lo cierra sin navegar (I6)',
    (tester) async {
      await tester.pumpWidget(host());
      await openPanel(tester);
      expect(panelCubit.isOpen, isTrue);

      // El back del sistema: PopScope lo intercepta y cierra el panel.
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue, reason: 'el back fue consumido, no navegó');
      expect(panelCubit.isOpen, isFalse);
      // El composer sigue montado (no hubo pop de la pantalla).
      expect(find.byKey(const Key('composer.input')), findsOneWidget);
    },
  );
}
