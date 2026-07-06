import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/repositories/media_byte_store.dart';
import 'package:ataulfo/features/messages/data/cache/message_media_cache.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/presentation/widgets/message_media.dart';
import 'package:ataulfo/features/messages/presentation/widgets/video_playback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemByteStore implements MediaByteStore {
  final Map<String, Uint8List> _m = <String, Uint8List>{};

  @override
  Future<Uint8List?> read(String ref) async => _m[ref];

  @override
  Future<void> write(String ref, Uint8List bytes) async {
    _m[ref] = bytes;
  }
}

/// Registra cada apertura (URL y/o bytes) sin tocar el plugin de video.
class _FakeVideoPlayback implements VideoPlayback {
  final List<({String? url, Uint8List? bytes})> opens =
      <({String? url, Uint8List? bytes})>[];

  @override
  Future<void> open(
    BuildContext context, {
    String? url,
    Uint8List? bytes,
    String? cacheKey,
  }) async {
    opens.add((url: url, bytes: bytes));
  }
}

Message _videoMsg({String? mediaRef, String? mediaUrl}) => Message(
  externalId: 'v1',
  chatLid: 'lid-1',
  senderLid: 'alice',
  kind: MessageKind.dm,
  direction: MessageDirection.inbound,
  type: 'video',
  content: '',
  mediaRef: mediaRef,
  mediaUrl: mediaUrl,
  quotedId: null,
  timestampMs: 1700,
  status: null,
);

void main() {
  final videoBytes = Uint8List.fromList(<int>[9, 9, 9, 9]);

  Widget host({
    required Message message,
    required MessageMediaCache cache,
    required VideoPlayback playback,
  }) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: RepositoryProvider<MessageMediaCache>.value(
        value: cache,
        child: RepositoryProvider<VideoPlayback>.value(
          value: playback,
          child: MessageMediaContent(message: message),
        ),
      ),
    ),
  );

  testWidgets('video con bytes cacheados reproduce SIN tocar la red', (
    tester,
  ) async {
    var downloads = 0;
    final cache = MessageMediaCache(
      store: _MemByteStore(),
      download: (_) async {
        downloads++;
        return null;
      },
    );
    await cache.cache('ref-v', videoBytes);
    final playback = _FakeVideoPlayback();

    await tester.pumpWidget(
      host(
        message: _videoMsg(mediaRef: 'ref-v'),
        cache: cache,
        playback: playback,
      ),
    );

    // La burbuja de video existe aun sin URL firmada: la copia local basta.
    await tester.tap(find.byKey(const Key('message.video.v1')));
    await tester.pumpAndSettle();

    expect(downloads, 0, reason: 'con caché en disco no se toca la red');
    expect(playback.opens, hasLength(1));
    expect(playback.opens.single.bytes, videoBytes);
  });

  testWidgets('video sin caché con URL viva: descarga una vez y reproduce', (
    tester,
  ) async {
    var downloads = 0;
    final cache = MessageMediaCache(
      store: _MemByteStore(),
      download: (_) async {
        downloads++;
        return videoBytes;
      },
    );
    final playback = _FakeVideoPlayback();

    await tester.pumpWidget(
      host(
        message: _videoMsg(mediaRef: 'ref-v', mediaUrl: 'https://cdn/v.mp4'),
        cache: cache,
        playback: playback,
      ),
    );

    await tester.tap(find.byKey(const Key('message.video.v1')));
    await tester.pumpAndSettle();

    expect(downloads, 1);
    expect(playback.opens, hasLength(1));
    expect(playback.opens.single.bytes, videoBytes);
  });

  testWidgets('video sin caché y sin URL: aviso, no reproduce', (tester) async {
    final cache = MessageMediaCache(
      store: _MemByteStore(),
      download: (_) async => null,
    );
    final playback = _FakeVideoPlayback();

    await tester.pumpWidget(
      host(
        message: _videoMsg(mediaRef: 'ref-v'),
        cache: cache,
        playback: playback,
      ),
    );

    await tester.tap(find.byKey(const Key('message.video.v1')));
    await tester.pumpAndSettle();

    expect(playback.opens, isEmpty);
    expect(find.text('No se pudo reproducir el video'), findsOneWidget);
  });
}
