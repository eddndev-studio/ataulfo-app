import 'dart:convert';

import 'package:ataulfo/features/messages/data/cache/message_media_cache.dart';
import 'package:ataulfo/features/messages/domain/repositories/media_opener.dart';
import 'package:ataulfo/features/messages/presentation/bloc/thread_audio_cubit.dart';
import 'package:ataulfo/features/messages/presentation/widgets/video_playback.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_attachment.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/presentation/widgets/trainer_message_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_chat_media.dart';
import '../../../support/fake_message_media_cache.dart';

/// 1x1 PNG válido: que Image.memory decodifique sin caer al errorBuilder.
final _pngBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  ),
);

TrainerMessage _userMsg(TrainerAttachment att) => TrainerMessage(
  id: 'm1',
  conversationId: 'c1',
  role: 'user',
  content: '',
  attachments: <TrainerAttachment>[att],
  createdAt: DateTime.utc(2026, 6, 10, 10),
);

class _FakeVideoPlayback implements VideoPlayback {
  final List<String> calls = <String>[];

  @override
  Future<void> open(BuildContext context, {required String url}) async {
    calls.add(url);
  }
}

Future<ThreadAudioCubit> _pump(
  WidgetTester tester,
  TrainerMessage message, {
  MessageMediaCache? cache,
}) async {
  final audio = ThreadAudioCubit(engine: const FakeAudioEngine());
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MultiRepositoryProvider(
          providers: <RepositoryProvider<dynamic>>[
            RepositoryProvider<MessageMediaCache>.value(
              value: cache ?? fakeMessageMediaCache(),
            ),
            RepositoryProvider<MediaOpener>.value(
              value: const FakeMediaOpener(),
            ),
            RepositoryProvider<VideoPlayback>.value(
              value: _FakeVideoPlayback(),
            ),
          ],
          child: BlocProvider<ThreadAudioCubit>.value(
            value: audio,
            child: SingleChildScrollView(
              child: TrainerMessageTile(message: message),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(audio.close);
  return audio;
}

void main() {
  testWidgets('adjunto imagen con bytes en caché pinta miniatura', (
    tester,
  ) async {
    const att = TrainerAttachment(
      ref: 'org/media/foto.png',
      mime: 'image/png',
      name: 'foto.png',
      sizeBytes: 4,
    );
    final cache = fakeMessageMediaCache();
    await cache.cache(att.ref, _pngBytes);
    await _pump(tester, _userMsg(att), cache: cache);
    expect(
      find.byKey(const Key('message.image.m1.org/media/foto.png')),
      findsOneWidget,
    );
  });

  testWidgets('adjunto imagen sin bytes degrada a tarjeta con su nombre', (
    tester,
  ) async {
    const att = TrainerAttachment(
      ref: 'org/media/foto.png',
      mime: 'image/png',
      name: 'foto.png',
      sizeBytes: 4,
    );
    await _pump(tester, _userMsg(att));
    expect(find.text('foto.png'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  testWidgets('adjunto audio pinta burbuja reproducible', (tester) async {
    const att = TrainerAttachment(
      ref: 'org/media/cancion.mp3',
      mime: 'audio/mpeg',
      name: 'cancion.mp3',
      sizeBytes: 4,
    );
    await _pump(tester, _userMsg(att));
    expect(
      find.byKey(const Key('message.audio.m1.org/media/cancion.mp3.toggle')),
      findsOneWidget,
    );
  });

  testWidgets('adjunto video sin URL degrada a tarjeta con su nombre', (
    tester,
  ) async {
    const att = TrainerAttachment(
      ref: 'org/media/clip.mp4',
      mime: 'video/mp4',
      name: 'clip.mp4',
      sizeBytes: 4,
    );
    await _pump(tester, _userMsg(att));
    expect(find.text('clip.mp4'), findsOneWidget);
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
  });

  testWidgets('adjunto documento pinta tarjeta con nombre de archivo', (
    tester,
  ) async {
    const att = TrainerAttachment(
      ref: 'org/media/contrato.pdf',
      mime: 'application/pdf',
      name: 'contrato.pdf',
      sizeBytes: 4,
    );
    await _pump(tester, _userMsg(att));
    expect(find.text('contrato.pdf'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
  });

  testWidgets('adjunto video con URL firmada pinta burbuja reproducible', (
    tester,
  ) async {
    const att = TrainerAttachment(
      ref: 'org/media/clip.mp4',
      mime: 'video/mp4',
      name: 'clip.mp4',
      sizeBytes: 4,
      url: 'https://cdn.example/clip.mp4?sig=abc',
    );
    await _pump(tester, _userMsg(att));
    expect(
      find.byKey(const Key('message.video.m1.org/media/clip.mp4')),
      findsOneWidget,
    );
  });

  testWidgets('adjunto imagen sin caché con URL firmada descarga y pinta '
      'la miniatura', (tester) async {
    const att = TrainerAttachment(
      ref: 'org/media/foto.png',
      mime: 'image/png',
      name: 'foto.png',
      sizeBytes: 4,
      url: 'https://cdn.example/foto.png?sig=abc',
    );
    final cache = fakeMessageMediaCache(downloadResult: _pngBytes);
    await _pump(tester, _userMsg(att), cache: cache);
    expect(
      find.byKey(const Key('message.image.m1.org/media/foto.png')),
      findsOneWidget,
    );
  });

  testWidgets('adjunto imagen con bytes en caché no descarga aunque haya '
      'URL firmada', (tester) async {
    const att = TrainerAttachment(
      ref: 'org/media/foto.png',
      mime: 'image/png',
      name: 'foto.png',
      sizeBytes: 4,
      url: 'https://cdn.example/foto.png?sig=abc',
    );
    final downloads = <String>[];
    final cache = fakeMessageMediaCache(
      download: (url) async {
        downloads.add(url);
        return null;
      },
    );
    await cache.cache(att.ref, _pngBytes);
    await _pump(tester, _userMsg(att), cache: cache);
    expect(
      find.byKey(const Key('message.image.m1.org/media/foto.png')),
      findsOneWidget,
    );
    expect(downloads, isEmpty);
  });

  testWidgets('adjunto documento con URL firmada es tocable', (tester) async {
    const att = TrainerAttachment(
      ref: 'org/media/contrato.pdf',
      mime: 'application/pdf',
      name: 'contrato.pdf',
      sizeBytes: 4,
      url: 'https://cdn.example/contrato.pdf?sig=abc',
    );
    await _pump(tester, _userMsg(att));
    expect(
      find.byKey(const Key('message.doc.m1.org/media/contrato.pdf')),
      findsOneWidget,
    );
    expect(find.text('Toca para abrir'), findsOneWidget);
  });

  testWidgets('nota de voz sin caché con URL firmada reproduce por streaming', (
    tester,
  ) async {
    final voice = TrainerMessage(
      id: 'v1',
      conversationId: 'c1',
      role: 'user',
      content: '[audio]',
      audioRef: 'org/media/nota.ogg',
      audioUrl: 'https://cdn.example/nota.ogg?sig=abc',
      createdAt: DateTime.utc(2026, 6, 10, 10),
    );
    final audio = await _pump(tester, voice);
    await tester.tap(find.byKey(const Key('message.audio.v1.toggle')));
    await tester.pumpAndSettle();
    expect(audio.state.sourceKey, 'org/media/nota.ogg');
  });
}
