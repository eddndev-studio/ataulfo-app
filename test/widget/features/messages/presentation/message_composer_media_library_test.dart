import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/data/repositories/noop_camera_capture.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/repositories/camera_capture.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/messages/data/media/noop_audio_recorder.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/core/audio/audio_recorder.dart';
import 'package:ataulfo/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:ataulfo/features/messages/presentation/bloc/reply_draft_cubit.dart';
import 'package:ataulfo/features/messages/presentation/widgets/message_composer.dart';
import 'package:ataulfo/features/quick_replies/presentation/bloc/quick_replies_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockMessagesBloc extends MockBloc<MessagesEvent, MessagesState>
    implements MessagesBloc {}

class _MockQuickRepliesBloc
    extends MockBloc<QuickRepliesEvent, QuickRepliesState>
    implements QuickRepliesBloc {}

class _MockFilePicker extends Mock implements MediaFilePicker {}

class _MockMediaRepo extends Mock implements MediaRepository {}

/// El destino "Medios" del menú de adjuntar a nivel de RUTA: el composer hace
/// `context.push('/media/pick')` y el picker devuelve un [MediaAsset] entero
/// vía pop. El asset entra a la bandeja como adjunto YA SUBIDO: al enviar, ese
/// ítem NO pasa por `upload` y despacha su ref BARE tal cual (nunca la
/// previewUrl efímera).
void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const MessagesLoadRequested());
  });

  // Ref BARE canónico ≠ previewUrl firmada: si el composer despachara la URL
  // (o volviera a subir), las aserciones de ref exacto fallarían.
  const bareRef = 'tenant/org1/media/contrato.pdf';
  const signedUrl = 'https://signed.example/contrato?sig=ephemeral';
  final docAsset = MediaAsset(
    ref: bareRef,
    previewUrl: signedUrl,
    filename: 'contrato.pdf',
    contentType: 'application/pdf',
    size: 2048,
    createdAt: DateTime.utc(2026, 1, 1),
  );
  const imageBareRef = 'tenant/org1/media/foto.png';
  const imageSignedUrl = 'https://signed.example/foto.png?sig=ephemeral';
  final imageAsset = MediaAsset(
    ref: imageBareRef,
    previewUrl: imageSignedUrl,
    filename: 'foto.png',
    contentType: 'image/png',
    size: 512,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  late _MockMessagesBloc msgBloc;
  late _MockQuickRepliesBloc qrBloc;
  late _MockFilePicker picker;
  late _MockMediaRepo mediaRepo;

  /// Asset que la ruta fake `/media/pick` devuelve por pop al "elegir".
  late MediaAsset assetToPick;

  setUp(() {
    msgBloc = _MockMessagesBloc();
    qrBloc = _MockQuickRepliesBloc();
    picker = _MockFilePicker();
    mediaRepo = _MockMediaRepo();
    assetToPick = docAsset;
    when(() => msgBloc.state).thenReturn(
      const MessagesLoaded(
        items: <Message>[],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    when(() => qrBloc.state).thenReturn(const QuickRepliesLoading());
    when(
      () => mediaRepo.upload(
        bytes: any(named: 'bytes'),
        filename: any(named: 'filename'),
      ),
    ).thenAnswer((inv) async {
      final name = inv.namedArguments[#filename] as String;
      return UploadedMedia(ref: 'ref-$name', previewUrl: null);
    });
  });

  // Monta el composer bajo un GoRouter con la ruta REAL que el destino
  // "Medios" pushea: `/media/pick` aquí es una página fake que devuelve
  // [assetToPick] entero vía pop (mismo contrato que la galería-picker real).
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
        ),
        GoRoute(
          path: '/media/pick',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ElevatedButton(
                    key: const Key('fake_media_pick.pick'),
                    onPressed: () => context.pop(assetToPick),
                    child: const Text('elegir'),
                  ),
                  ElevatedButton(
                    key: const Key('fake_media_pick.cancel'),
                    onPressed: () => context.pop(),
                    child: const Text('cancelar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
    );
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('composer.attach')));
    await tester.pumpAndSettle();
  }

  Future<void> tapMedios(WidgetTester tester) async {
    await openMenu(tester);
    await tester.tap(find.byKey(const Key('attach_menu.media')));
    await tester.pumpAndSettle();
  }

  List<MessagesSendRequested> sentEvents() => verify(
    () => msgBloc.add(captureAny()),
  ).captured.cast<MessagesSendRequested>();

  testWidgets(
    'Medios: push a /media/pick y el asset elegido entra a la bandeja',
    (tester) async {
      await pumpHost(tester);
      await tapMedios(tester);

      // Estamos en la ruta pusheada, no en el hilo.
      expect(find.byKey(const Key('fake_media_pick.pick')), findsOneWidget);
      await tester.tap(find.byKey(const Key('fake_media_pick.pick')));
      await tester.pumpAndSettle();

      // De vuelta en el hilo, la bandeja muestra el documento con el peso
      // reportado por el servidor (no hay bytes locales).
      expect(find.byKey(const Key('composer.attachment_tray')), findsOneWidget);
      expect(find.text('contrato.pdf'), findsOneWidget);
      expect(find.text('2 KB'), findsOneWidget);
    },
  );

  testWidgets('cancelar el picker (pop null) no agrega nada', (tester) async {
    await pumpHost(tester);
    await tapMedios(tester);
    await tester.tap(find.byKey(const Key('fake_media_pick.cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('composer.attachment_tray')), findsNothing);
  });

  testWidgets(
    'enviar un adjunto ya subido NO llama upload y despacha su ref BARE',
    (tester) async {
      await pumpHost(tester);
      await tapMedios(tester);
      await tester.tap(find.byKey(const Key('fake_media_pick.pick')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('composer.attach_send')));
      await tester.pumpAndSettle();

      verifyNever(
        () => mediaRepo.upload(
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      );
      final events = sentEvents();
      expect(events.length, 1);
      expect(events[0].type, 'document');
      expect(events[0].mediaRef, bareRef);
      expect(events[0].mediaRef, isNot(signedUrl));
      expect(events[0].fileName, 'contrato.pdf');

      // La bandeja se vació tras el envío.
      expect(find.byKey(const Key('composer.attachment_tray')), findsNothing);
    },
  );

  testWidgets(
    'una imagen del catálogo despacha type image con el ref, sin fileName',
    (tester) async {
      assetToPick = imageAsset;
      await pumpHost(tester);
      await tapMedios(tester);
      await tester.tap(find.byKey(const Key('fake_media_pick.pick')));
      await tester.pumpAndSettle();

      // La miniatura de la bandeja intenta la URL firmada (no hay bytes).
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const Key('composer.attachment_tray.item.0')),
          matching: find.byType(Image),
        ),
      );
      expect(image.image, isA<NetworkImage>());
      expect((image.image as NetworkImage).url, imageSignedUrl);

      await tester.tap(find.byKey(const Key('composer.attach_send')));
      await tester.pumpAndSettle();

      verifyNever(
        () => mediaRepo.upload(
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      );
      final events = sentEvents();
      expect(events.length, 1);
      expect(events[0].type, 'image');
      expect(events[0].mediaRef, imageBareRef);
      expect(events[0].fileName, isNull);
    },
  );

  testWidgets(
    'un video del catálogo cae a la cara de archivo y despacha su ref BARE',
    (tester) async {
      // Trae poster derivado (thumbnailUrl) ⇒ previewUrl del adjunto NO nulo,
      // pero al no ser imagen la tarjeta jamás pinta la miniatura: cae a la
      // cara de archivo, igual que un video local.
      const videoBareRef = 'tenant/org1/media/clip.mp4';
      assetToPick = MediaAsset(
        ref: videoBareRef,
        previewUrl: 'https://signed.example/clip.mp4?sig=ephemeral',
        thumbnailUrl: 'https://signed.example/clip-poster.jpg?sig=ephemeral',
        filename: 'clip.mp4',
        contentType: 'video/mp4',
        size: 4096,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      await pumpHost(tester);
      await tapMedios(tester);
      await tester.tap(find.byKey(const Key('fake_media_pick.pick')));
      await tester.pumpAndSettle();

      // Cara de archivo (nombre + peso), sin miniatura de red.
      final item = find.byKey(const Key('composer.attachment_tray.item.0'));
      expect(item, findsOneWidget);
      expect(
        find.descendant(of: item, matching: find.byType(Image)),
        findsNothing,
      );
      expect(find.text('clip.mp4'), findsOneWidget);
      expect(find.text('4 KB'), findsOneWidget);

      await tester.tap(find.byKey(const Key('composer.attach_send')));
      await tester.pumpAndSettle();

      verifyNever(
        () => mediaRepo.upload(
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      );
      final events = sentEvents();
      expect(events.length, 1);
      expect(events[0].type, 'video');
      expect(events[0].mediaRef, videoBareRef);
      expect(events[0].fileName, isNull);
    },
  );

  testWidgets(
    'lote mixto: el local sube, el ya subido no; caption en el primero',
    (tester) async {
      when(picker.pickMultiple).thenAnswer(
        (_) async => <PickedMedia>[
          PickedMedia(bytes: Uint8List(8), filename: 'a.png'),
        ],
      );
      await pumpHost(tester);

      // Primero el local (Documento), luego el del catálogo (Medios).
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('attach_menu.document')));
      await tester.pumpAndSettle();
      await tapMedios(tester);
      await tester.tap(find.byKey(const Key('fake_media_pick.pick')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('composer.input')), 'mira');
      await tester.pump();
      await tester.tap(find.byKey(const Key('composer.send')));
      await tester.pumpAndSettle();

      // Subió EXACTAMENTE el local; el del catálogo no tocó la red.
      verify(
        () => mediaRepo.upload(
          bytes: any(named: 'bytes'),
          filename: 'a.png',
        ),
      ).called(1);
      verifyNoMoreInteractions(mediaRepo);

      final events = sentEvents();
      expect(events.length, 2);
      expect(events[0].type, 'image');
      expect(events[0].content, 'mira');
      expect(events[0].mediaRef, 'ref-a.png');
      expect(events[1].type, 'document');
      expect(events[1].content, '');
      expect(events[1].mediaRef, bareRef);
      expect(events[1].fileName, 'contrato.pdf');
    },
  );

  testWidgets('con la bandeja llena (10), Medios avisa y no agrega', (
    tester,
  ) async {
    when(picker.pickMultiple).thenAnswer(
      (_) async => <PickedMedia>[
        for (var i = 0; i < 10; i++)
          PickedMedia(bytes: Uint8List(1), filename: 'f$i.pdf'),
      ],
    );
    await pumpHost(tester);
    await openMenu(tester);
    await tester.tap(find.byKey(const Key('attach_menu.document')));
    await tester.pumpAndSettle();
    expect(find.text('10 archivos'), findsOneWidget);

    await tapMedios(tester);
    await tester.tap(find.byKey(const Key('fake_media_pick.pick')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Máximo 10'), findsOneWidget);
    expect(find.text('10 archivos'), findsOneWidget);
  });
}
