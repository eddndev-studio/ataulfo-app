import 'dart:convert';

import 'package:ataulfo/features/messages/data/cache/message_media_cache.dart';
import 'package:ataulfo/features/messages/domain/repositories/media_opener.dart';
import 'package:ataulfo/features/messages/presentation/bloc/thread_audio_cubit.dart';
import 'package:ataulfo/features/messages/presentation/widgets/audio_failures_listener.dart';
import 'package:ataulfo/features/messages/presentation/widgets/video_playback.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_attachment.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_message.dart';
import 'package:ataulfo/features/platform_agent/presentation/widgets/pa_message_tile.dart';
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

PaMessage _userMsg({
  List<PaAttachment> attachments = const <PaAttachment>[],
  String content = '',
  String audioRef = '',
  String audioUrl = '',
  String transcriptStatus = '',
  String transcript = '',
}) => PaMessage(
  id: 'm1',
  conversationId: 'c1',
  role: 'user',
  content: content,
  attachments: attachments,
  audioRef: audioRef,
  audioUrl: audioUrl,
  transcriptStatus: transcriptStatus,
  transcript: transcript,
  createdAt: DateTime.utc(2026, 6, 10, 10),
);

class _FakeVideoPlayback implements VideoPlayback {
  final List<String> calls = <String>[];

  @override
  Future<void> open(
    BuildContext context, {
    String? url,
    Uint8List? bytes,
    String? cacheKey,
  }) async {
    calls.add(url ?? cacheKey ?? '');
  }
}

Future<ThreadAudioCubit> _pump(
  WidgetTester tester,
  PaMessage message, {
  MessageMediaCache? cache,
}) async {
  final audio = ThreadAudioCubit(engine: const FakeAudioEngine());
  await tester.pumpWidget(
    // Los providers van SOBRE el MaterialApp (no dentro de `home`): el visor
    // de galería, al abrirse en una ruta empujada, necesita seguir viendo
    // MessageMediaCache — las rutas empujadas no heredan providers montados
    // dentro de la ruta inicial.
    MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<MessageMediaCache>.value(
          value: cache ?? fakeMessageMediaCache(),
        ),
        RepositoryProvider<MediaOpener>.value(value: const FakeMediaOpener()),
        RepositoryProvider<VideoPlayback>.value(value: _FakeVideoPlayback()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: BlocProvider<ThreadAudioCubit>.value(
            value: audio,
            child: AudioFailuresListener(
              child: SingleChildScrollView(
                child: PaMessageTile(message: message),
              ),
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
    const att = PaAttachment(
      ref: 'org/media/foto.png',
      mime: 'image/png',
      name: 'foto.png',
      sizeBytes: 4,
    );
    final cache = fakeMessageMediaCache();
    await cache.cache(att.ref, _pngBytes);
    await _pump(
      tester,
      _userMsg(attachments: const <PaAttachment>[att]),
      cache: cache,
    );
    expect(
      find.byKey(const Key('message.image.m1.org/media/foto.png')),
      findsOneWidget,
    );
  });

  testWidgets('adjunto imagen sin bytes degrada a tarjeta con su nombre', (
    tester,
  ) async {
    const att = PaAttachment(
      ref: 'org/media/foto.png',
      mime: 'image/png',
      name: 'foto.png',
      sizeBytes: 4,
    );
    await _pump(tester, _userMsg(attachments: const <PaAttachment>[att]));
    expect(find.text('foto.png'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  testWidgets('adjunto audio pinta burbuja reproducible', (tester) async {
    const att = PaAttachment(
      ref: 'org/media/cancion.mp3',
      mime: 'audio/mpeg',
      name: 'cancion.mp3',
      sizeBytes: 4,
    );
    await _pump(tester, _userMsg(attachments: const <PaAttachment>[att]));
    expect(
      find.byKey(const Key('message.audio.m1.org/media/cancion.mp3.toggle')),
      findsOneWidget,
    );
  });

  testWidgets(
    'adjunto video sin URL ni caché pinta burbuja reproducible que avisa '
    'al tocar sin nada que reproducir',
    (tester) async {
      const att = PaAttachment(
        ref: 'org/media/clip.mp4',
        mime: 'video/mp4',
        name: 'clip.mp4',
        sizeBytes: 4,
      );
      await _pump(tester, _userMsg(attachments: const <PaAttachment>[att]));
      final key = find.byKey(const Key('message.video.m1.org/media/clip.mp4'));
      expect(key, findsOneWidget);
      await tester.tap(key);
      await tester.pumpAndSettle();
      expect(find.text('No se pudo reproducir el video'), findsOneWidget);
    },
  );

  testWidgets(
    'adjunto video con bytes en caché pinta burbuja reproducible aunque no '
    'haya URL firmada',
    (tester) async {
      const att = PaAttachment(
        ref: 'org/media/clip.mp4',
        mime: 'video/mp4',
        name: 'clip.mp4',
        sizeBytes: 4,
      );
      final cache = fakeMessageMediaCache();
      await cache.cache(att.ref, Uint8List.fromList(<int>[1, 2, 3]));
      await _pump(
        tester,
        _userMsg(attachments: const <PaAttachment>[att]),
        cache: cache,
      );
      expect(
        find.byKey(const Key('message.video.m1.org/media/clip.mp4')),
        findsOneWidget,
      );
    },
  );

  testWidgets('adjunto documento pinta tarjeta con nombre de archivo', (
    tester,
  ) async {
    const att = PaAttachment(
      ref: 'org/media/contrato.pdf',
      mime: 'application/pdf',
      name: 'contrato.pdf',
      sizeBytes: 4,
    );
    await _pump(tester, _userMsg(attachments: const <PaAttachment>[att]));
    expect(find.text('contrato.pdf'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
  });

  testWidgets('nota de voz transcrita: burbuja reproducible + transcrito', (
    tester,
  ) async {
    await _pump(
      tester,
      _userMsg(
        content: '[audio]',
        audioRef: 'org/media/nota.ogg',
        transcriptStatus: 'done',
        transcript: 'hola, ¿cómo va el pedido?',
      ),
    );
    expect(find.byKey(const Key('message.audio.m1.toggle')), findsOneWidget);
    expect(find.text('Nota de voz'), findsOneWidget);
    expect(find.text('hola, ¿cómo va el pedido?'), findsOneWidget);
    // El marcador crudo del wire no se pinta.
    expect(find.text('[audio]'), findsNothing);
  });

  testWidgets('nota de voz sin transcribir: reproducible, sin transcrito', (
    tester,
  ) async {
    await _pump(
      tester,
      _userMsg(
        content: '[audio]',
        audioRef: 'org/media/nota.ogg',
        transcriptStatus: 'pending',
      ),
    );
    expect(find.byKey(const Key('message.audio.m1.toggle')), findsOneWidget);
    expect(find.text('[audio]'), findsNothing);
  });

  testWidgets('nota de voz sin fuente: tocar play avisa con SnackBar', (
    tester,
  ) async {
    // Sin bytes locales ni URL (nota de otro dispositivo): el intento de
    // reproducción no debe fallar en silencio.
    await _pump(
      tester,
      _userMsg(content: '[audio]', audioRef: 'org/media/ajena.ogg'),
    );
    await tester.tap(find.byKey(const Key('message.audio.m1.toggle')));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo reproducir el audio'), findsOneWidget);
  });

  testWidgets('nota de voz con bytes en caché: tocar play activa la fuente', (
    tester,
  ) async {
    final cache = fakeMessageMediaCache();
    await cache.cache('org/media/nota.ogg', Uint8List.fromList(<int>[1, 2]));
    final audio = await _pump(
      tester,
      _userMsg(content: '[audio]', audioRef: 'org/media/nota.ogg'),
      cache: cache,
    );
    await tester.tap(find.byKey(const Key('message.audio.m1.toggle')));
    await tester.pumpAndSettle();
    expect(audio.state.sourceKey, 'org/media/nota.ogg');
  });

  testWidgets('adjunto video con URL firmada pinta burbuja reproducible', (
    tester,
  ) async {
    const att = PaAttachment(
      ref: 'org/media/clip.mp4',
      mime: 'video/mp4',
      name: 'clip.mp4',
      sizeBytes: 4,
      url: 'https://cdn.example/clip.mp4?sig=abc',
    );
    await _pump(tester, _userMsg(attachments: const <PaAttachment>[att]));
    expect(
      find.byKey(const Key('message.video.m1.org/media/clip.mp4')),
      findsOneWidget,
    );
  });

  testWidgets('adjunto imagen sin caché con URL firmada descarga y pinta '
      'la miniatura', (tester) async {
    const att = PaAttachment(
      ref: 'org/media/foto.png',
      mime: 'image/png',
      name: 'foto.png',
      sizeBytes: 4,
      url: 'https://cdn.example/foto.png?sig=abc',
    );
    final cache = fakeMessageMediaCache(downloadResult: _pngBytes);
    await _pump(
      tester,
      _userMsg(attachments: const <PaAttachment>[att]),
      cache: cache,
    );
    expect(
      find.byKey(const Key('message.image.m1.org/media/foto.png')),
      findsOneWidget,
    );
  });

  testWidgets('nota de voz sin caché con URL firmada reproduce por streaming '
      '(sin aviso de fallo)', (tester) async {
    final audio = await _pump(
      tester,
      _userMsg(
        content: '[audio]',
        audioRef: 'org/media/nota.ogg',
        audioUrl: 'https://cdn.example/nota.ogg?sig=abc',
      ),
    );
    await tester.tap(find.byKey(const Key('message.audio.m1.toggle')));
    await tester.pumpAndSettle();
    expect(audio.state.sourceKey, 'org/media/nota.ogg');
    expect(find.text('No se pudo reproducir el audio'), findsNothing);
  });

  testWidgets(
    'mensaje con varias fotos: tocar una abre galería deslizable entre ellas',
    (tester) async {
      const att1 = PaAttachment(
        ref: 'org/media/foto1.png',
        mime: 'image/png',
        name: 'foto1.png',
        sizeBytes: 4,
      );
      const att2 = PaAttachment(
        ref: 'org/media/foto2.png',
        mime: 'image/png',
        name: 'foto2.png',
        sizeBytes: 4,
      );
      final cache = fakeMessageMediaCache();
      await cache.cache(att1.ref, _pngBytes);
      await cache.cache(att2.ref, _pngBytes);
      await _pump(
        tester,
        _userMsg(attachments: const <PaAttachment>[att1, att2]),
        cache: cache,
      );
      await tester.tap(
        find.byKey(const Key('message.image.m1.org/media/foto1.png')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
    },
  );

  testWidgets(
    'mensaje con una sola foto abre el visor de siempre (sin índice)',
    (tester) async {
      const att = PaAttachment(
        ref: 'org/media/foto.png',
        mime: 'image/png',
        name: 'foto.png',
        sizeBytes: 4,
      );
      final cache = fakeMessageMediaCache();
      await cache.cache(att.ref, _pngBytes);
      await _pump(
        tester,
        _userMsg(attachments: const <PaAttachment>[att]),
        cache: cache,
      );
      await tester.tap(
        find.byKey(const Key('message.image.m1.org/media/foto.png')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
    },
  );
}
