import 'package:ataulfo/features/messages/data/cache/message_media_cache.dart';
import 'package:ataulfo/features/messages/domain/repositories/media_opener.dart';
import 'package:ataulfo/features/messages/presentation/bloc/thread_audio_cubit.dart';
import 'package:ataulfo/features/messages/presentation/widgets/video_playback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'fake_chat_media.dart';
import 'fake_message_media_cache.dart';

/// [VideoPlayback] inerte que registra las URLs abiertas (el puerto recibe el
/// BuildContext, así que no se presta a un mock).
class RecordingVideoPlayback implements VideoPlayback {
  final List<String> calls = <String>[];

  @override
  Future<void> open(BuildContext context, {required String url}) async {
    calls.add(url);
  }
}

/// Envuelve [child] con las dependencias que el renderer compartido de
/// adjuntos ([AttachmentContent]/[AudioMessageContent]) exige en contexto:
/// caché de bytes, player de audio del hilo, abridor de documentos y
/// reproductor de video. Para tests de páginas/tiles de los chats de agentes.
Widget wrapWithChatMedia(Widget child, {MessageMediaCache? cache}) =>
    MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<MessageMediaCache>.value(
          value: cache ?? fakeMessageMediaCache(),
        ),
        RepositoryProvider<MediaOpener>.value(value: const FakeMediaOpener()),
        RepositoryProvider<VideoPlayback>.value(
          value: RecordingVideoPlayback(),
        ),
      ],
      child: BlocProvider<ThreadAudioCubit>(
        create: (_) => ThreadAudioCubit(engine: const FakeAudioEngine()),
        child: child,
      ),
    );
