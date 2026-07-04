import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/failures/media_failure.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/messages/data/media/noop_audio_recorder.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/domain/repositories/audio_recorder.dart';
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

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const MessagesLoadRequested());
  });

  late _MockMessagesBloc msgBloc;
  late _MockQuickRepliesBloc qrBloc;
  late _MockFilePicker picker;
  late _MockMediaRepo mediaRepo;
  late ReplyDraftCubit replyDraft;

  setUp(() {
    msgBloc = _MockMessagesBloc();
    qrBloc = _MockQuickRepliesBloc();
    picker = _MockFilePicker();
    mediaRepo = _MockMediaRepo();
    replyDraft = ReplyDraftCubit();
    when(() => msgBloc.state).thenReturn(
      const MessagesLoaded(
        items: <Message>[],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    when(() => qrBloc.state).thenReturn(const QuickRepliesLoading());
    // Cada subida devuelve un ref derivado del nombre para poder aseverar orden.
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

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<MediaFilePicker>.value(value: picker),
        RepositoryProvider<MediaRepository>.value(value: mediaRepo),
        RepositoryProvider<AudioRecorder>.value(
          value: const NoopAudioRecorder(),
        ),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<MessagesBloc>.value(value: msgBloc),
          BlocProvider<QuickRepliesBloc>.value(value: qrBloc),
          BlocProvider<ReplyDraftCubit>.value(value: replyDraft),
        ],
        child: const Scaffold(body: MessageComposer()),
      ),
    ),
  );

  PickedMedia pm(String name, {int size = 8}) =>
      PickedMedia(bytes: Uint8List(size), filename: name);

  List<MessagesSendRequested> sentEvents() => verify(
    () => msgBloc.add(captureAny()),
  ).captured.cast<MessagesSendRequested>();

  testWidgets('adjuntar usa pickMultiple y llena la bandeja', (tester) async {
    when(
      picker.pickMultiple,
    ).thenAnswer((_) async => <PickedMedia>[pm('a.png'), pm('b.pdf')]);

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('composer.attach')));
    await tester.pump();

    verify(picker.pickMultiple).called(1);
    expect(find.byKey(const Key('composer.attachment_tray')), findsOneWidget);
    expect(find.text('b.pdf'), findsOneWidget);
  });

  testWidgets(
    'enviar despacha un evento por archivo en orden: caption + quotedId sólo '
    'en el primero; fileName sólo en el documento',
    (tester) async {
      // Cita en curso: debe consumirse con el lote (sólo el primer mensaje).
      replyDraft.setReply(
        const Message(
          externalId: 'orig-1',
          chatLid: 'c1',
          senderLid: 's1',
          kind: MessageKind.dm,
          direction: MessageDirection.inbound,
          type: 'text',
          content: 'hola',
          mediaRef: null,
          quotedId: null,
          timestampMs: 1000,
          status: null,
        ),
      );
      when(picker.pickMultiple).thenAnswer(
        (_) async => <PickedMedia>[pm('a.png'), pm('doc.pdf'), pm('clip.mp4')],
      );

      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('composer.attach')));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('composer.input')), 'mira');
      await tester.pump();
      await tester.tap(find.byKey(const Key('composer.send')));
      await tester.pump();
      await tester.pumpAndSettle();

      final events = sentEvents();
      expect(events.length, 3);

      expect(events[0].type, 'image');
      expect(events[0].content, 'mira');
      expect(events[0].mediaRef, 'ref-a.png');
      expect(events[0].fileName, isNull);
      expect(events[0].quotedId, 'orig-1');

      expect(events[1].type, 'document');
      expect(events[1].content, '');
      expect(events[1].mediaRef, 'ref-doc.pdf');
      expect(events[1].fileName, 'doc.pdf');
      expect(events[1].quotedId, isNull);

      expect(events[2].type, 'video');
      expect(events[2].content, '');
      expect(events[2].mediaRef, 'ref-clip.mp4');
      expect(events[2].fileName, isNull);
      expect(events[2].quotedId, isNull);

      // La cita se consumió; la bandeja se vació.
      expect(replyDraft.state, isNull);
      expect(find.byKey(const Key('composer.attachment_tray')), findsNothing);
    },
  );

  testWidgets(
    'un audio al frente del lote no se queda con el caption (content vacío); '
    'pasa al siguiente que lo admite',
    (tester) async {
      when(
        picker.pickMultiple,
      ).thenAnswer((_) async => <PickedMedia>[pm('nota.mp3'), pm('foto.png')]);

      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('composer.attach')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('composer.input')), 'hola');
      await tester.pump();
      await tester.tap(find.byKey(const Key('composer.send')));
      await tester.pump();
      await tester.pumpAndSettle();

      final events = sentEvents();
      expect(events.length, 2);
      expect(events[0].type, 'audio');
      expect(events[0].content, ''); // el audio NUNCA lleva caption
      expect(events[1].type, 'image');
      expect(events[1].content, 'hola'); // la leyenda cae en la imagen
    },
  );

  testWidgets('sin caption ni texto: el botón de la bandeja despacha el lote', (
    tester,
  ) async {
    when(
      picker.pickMultiple,
    ).thenAnswer((_) async => <PickedMedia>[pm('a.png')]);

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('composer.attach')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('composer.attach_send')));
    await tester.pump();
    await tester.pumpAndSettle();

    final events = sentEvents();
    expect(events.length, 1);
    expect(events[0].type, 'image');
    expect(events[0].content, '');
  });

  testWidgets('pasar de 10 archivos: avisa y recorta al tope', (tester) async {
    when(picker.pickMultiple).thenAnswer(
      (_) async => <PickedMedia>[for (var i = 0; i < 12; i++) pm('f$i.png')],
    );

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('composer.attach')));
    await tester.pump();

    expect(find.textContaining('Máximo 10'), findsOneWidget);
    // La bandeja quedó con 10 (contador exacto '10 archivos').
    expect(find.text('10 archivos'), findsOneWidget);
  });

  testWidgets('413 en la subida de un archivo: copy por archivo', (
    tester,
  ) async {
    when(
      picker.pickMultiple,
    ).thenAnswer((_) async => <PickedMedia>[pm('a.png'), pm('grande.pdf')]);
    when(
      () => mediaRepo.upload(
        bytes: any(named: 'bytes'),
        filename: 'grande.pdf',
      ),
    ).thenThrow(const MediaTooLargeFailure());

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('composer.attach')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer.attach_send')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('grande.pdf'), findsOneWidget);
    // El otro sí se despachó.
    final events = sentEvents();
    expect(events.length, 1);
    expect(events[0].mediaRef, 'ref-a.png');
  });
}
