import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/data/repositories/noop_camera_capture.dart';
import 'package:ataulfo/features/media/data/repositories/noop_device_gallery.dart';
import 'package:ataulfo/features/media/domain/repositories/camera_capture.dart';
import 'package:ataulfo/features/media/domain/repositories/device_gallery_port.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/messages/data/media/noop_audio_recorder.dart';
import 'package:ataulfo/core/audio/audio_recorder.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/presentation/bloc/attach_panel_cubit.dart';
import 'package:ataulfo/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:ataulfo/features/messages/presentation/bloc/reply_draft_cubit.dart';
import 'package:ataulfo/features/quick_replies/presentation/bloc/quick_replies_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/attach_thread_harness.dart';

class _MockMessagesBloc extends MockBloc<MessagesEvent, MessagesState>
    implements MessagesBloc {}

class _MockQuickRepliesBloc
    extends MockBloc<QuickRepliesEvent, QuickRepliesState>
    implements QuickRepliesBloc {}

class _MockFilePicker extends Mock implements MediaFilePicker {}

class _MockMediaRepo extends Mock implements MediaRepository {}

Message _reply(String externalId) => Message(
  externalId: externalId,
  chatLid: 'lid-1',
  senderLid: 'alice',
  kind: MessageKind.dm,
  direction: MessageDirection.inbound,
  type: 'text',
  content: 'hola',
  mediaRef: null,
  quotedId: null,
  timestampMs: 1700,
  status: null,
);

/// El destino "Stickers" del menú de adjuntar a nivel de RUTA: el composer hace
/// `context.push('/stickers/pick')` y el picker devuelve el REF de un sticker
/// vía pop. A diferencia de Medios, el sticker NO pasa por la bandeja: se
/// despacha al instante como `type: 'sticker'` con su ref.
void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const MessagesLoadRequested());
  });

  const stickerRef = 'tenant/org1/media/gracias.webp';

  late _MockMessagesBloc msgBloc;
  late _MockQuickRepliesBloc qrBloc;
  late _MockFilePicker picker;
  late _MockMediaRepo mediaRepo;

  /// Ref que la ruta fake `/stickers/pick` devuelve por pop; null ⇒ cancelar.
  late String? refToPick;
  Uri? pickedUri;
  late ReplyDraftCubit replyDraft;

  setUp(() {
    msgBloc = _MockMessagesBloc();
    qrBloc = _MockQuickRepliesBloc();
    picker = _MockFilePicker();
    mediaRepo = _MockMediaRepo();
    refToPick = stickerRef;
    pickedUri = null;
    replyDraft = ReplyDraftCubit();
    when(() => msgBloc.state).thenReturn(
      const MessagesLoaded(
        items: <Message>[],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    when(() => qrBloc.state).thenReturn(const QuickRepliesLoading());
  });

  Future<void> pumpHost(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/thread',
      routes: <RouteBase>[
        GoRoute(
          path: '/thread',
          builder: (_, _) => MultiRepositoryProvider(
            providers: <RepositoryProvider<dynamic>>[
              RepositoryProvider<MediaFilePicker>.value(value: picker),
              RepositoryProvider<MediaRepository>.value(value: mediaRepo),
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
                BlocProvider<ReplyDraftCubit>.value(value: replyDraft),
                BlocProvider<AttachPanelCubit>(
                  create: (_) => AttachPanelCubit(),
                ),
              ],
              child: const Scaffold(body: AttachThreadHarness()),
            ),
          ),
        ),
        GoRoute(
          path: '/stickers/pick',
          builder: (context, state) {
            pickedUri = state.uri;
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('fake_sticker_pick.pick'),
                  onPressed: () => context.pop(refToPick),
                  child: const Text('elegir'),
                ),
              ),
            );
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
    );
  }

  Future<void> tapStickers(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('composer.attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach_menu.stickers')));
    await tester.pumpAndSettle();
  }

  List<MessagesSendRequested> sentEvents() => verify(
    () => msgBloc.add(captureAny()),
  ).captured.whereType<MessagesSendRequested>().toList();

  testWidgets('Stickers: push a /stickers/pick y el ref se despacha al instante', (
    tester,
  ) async {
    await pumpHost(tester);
    await tapStickers(tester);

    // Estamos en la ruta pusheada del picker.
    expect(find.byKey(const Key('fake_sticker_pick.pick')), findsOneWidget);
    expect(pickedUri?.path, '/stickers/pick');
    await tester.tap(find.byKey(const Key('fake_sticker_pick.pick')));
    await tester.pumpAndSettle();

    final events = sentEvents();
    expect(events.length, 1);
    expect(events[0].type, 'sticker');
    expect(events[0].mediaRef, stickerRef);
    expect(events[0].content, '');
    expect(events[0].quotedId, isNull);
  });

  testWidgets('cancelar el picker (pop null) no despacha nada', (tester) async {
    refToPick = null;
    await pumpHost(tester);
    await tapStickers(tester);
    await tester.tap(find.byKey(const Key('fake_sticker_pick.pick')));
    await tester.pumpAndSettle();

    verifyNever(() => msgBloc.add(any(that: isA<MessagesSendRequested>())));
  });

  testWidgets('con una respuesta en curso, el sticker la cita y limpia el borrador', (
    tester,
  ) async {
    await pumpHost(tester);
    replyDraft.setReply(_reply('wamid-42'));

    await tapStickers(tester);
    await tester.tap(find.byKey(const Key('fake_sticker_pick.pick')));
    await tester.pumpAndSettle();

    final events = sentEvents();
    expect(events.length, 1);
    expect(events[0].type, 'sticker');
    expect(events[0].quotedId, 'wamid-42');
    // El borrador de respuesta se limpió tras enviar.
    expect(replyDraft.state, isNull);
  });
}
