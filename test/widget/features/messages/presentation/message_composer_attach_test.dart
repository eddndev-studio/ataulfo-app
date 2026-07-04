import 'dart:async';
import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
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

  setUp(() {
    msgBloc = _MockMessagesBloc();
    qrBloc = _MockQuickRepliesBloc();
    picker = _MockFilePicker();
    mediaRepo = _MockMediaRepo();
    when(() => msgBloc.state).thenReturn(
      const MessagesLoaded(
        items: <Message>[],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    when(() => qrBloc.state).thenReturn(const QuickRepliesLoading());
  });

  // Monta (o desmonta, con [show] false) el composer bajo sus dependencias. Al
  // pasar de show:true a show:false se dispone el State del composer (y su
  // TextEditingController), espejando lo que ocurre cuando el hilo transita a
  // Loading/Failed y oculta el composer.
  Widget host({required bool show}) => MaterialApp(
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
          BlocProvider<ReplyDraftCubit>(create: (_) => ReplyDraftCubit()),
        ],
        child: Scaffold(
          body: show ? const MessageComposer() : const SizedBox.shrink(),
        ),
      ),
    ),
  );

  testWidgets(
    'desmontar el composer durante la subida no lanza ni despacha (guarda '
    'mounted tras el await de upload)',
    (tester) async {
      final upload = Completer<UploadedMedia>();
      when(picker.pickMultiple).thenAnswer(
        (_) async => <PickedMedia>[
          PickedMedia(bytes: Uint8List(0), filename: 'a.png'),
        ],
      );
      when(
        () => mediaRepo.upload(
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      ).thenAnswer((_) => upload.future);

      await tester.pumpWidget(host(show: true));
      await tester.tap(find.byKey(const Key('composer.attach')));
      await tester.pump(); // resuelve pickMultiple() y llena la bandeja
      // Con la bandeja llena y el campo vacío, el slot final es el botón de
      // enviar el lote; al tocarlo la subida entra en vuelo.
      await tester.tap(find.byKey(const Key('composer.attach_send')));
      await tester.pump();

      // Desmonta el composer con la subida AÚN en vuelo: dispone _ctrl.
      await tester.pumpWidget(host(show: false));
      await tester.pump();

      // La subida resuelve DESPUÉS del dispose: la continuación de _sendBatch
      // corre sobre un widget desmontado. Con la guarda mounted no toca _ctrl
      // ni despacha sobre el bloc.
      upload.complete(const UploadedMedia(ref: 'ref-abc', previewUrl: null));
      await tester.pump();

      expect(tester.takeException(), isNull);
      verifyNever(() => msgBloc.add(any()));
    },
  );
}
