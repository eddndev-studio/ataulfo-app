import 'dart:convert';
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

class _NoopVideoPlayback implements VideoPlayback {
  @override
  Future<void> open(
    BuildContext context, {
    String? url,
    Uint8List? bytes,
    String? cacheKey,
  }) async {}
}

/// PNG gris de 300×300 (decodificable de verdad: la semántica de la foto se
/// poda del árbol si el render no tiene tamaño).
final _pngBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAASwAAAEsCAIAAAD2HxkiAAADUklEQVR4nO3TMQEAAAiAMKMb3Rgcbgl4mAVSUwfAdyaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIXYycHbi70aCGAAAAABJRU5ErkJggg==',
  ),
);

Message _msg({required String type, String? mediaRef, String? mediaUrl}) =>
    Message(
      externalId: 'm1',
      chatLid: 'lid-1',
      senderLid: 'alice',
      kind: MessageKind.dm,
      direction: MessageDirection.inbound,
      type: type,
      content: '',
      mediaRef: mediaRef,
      mediaUrl: mediaUrl,
      quotedId: null,
      timestampMs: 1700,
      status: null,
    );

Widget _host({required Message message, required MessageMediaCache cache}) =>
    MaterialApp(
      theme: AppDesignTheme.dark(),
      home: Scaffold(
        body: RepositoryProvider<MessageMediaCache>.value(
          value: cache,
          child: RepositoryProvider<VideoPlayback>.value(
            value: _NoopVideoPlayback(),
            child: MessageMediaContent(message: message),
          ),
        ),
      ),
    );

void main() {
  testWidgets('imagen fallida ofrece Reintentar que ignora el TTL de fallo', (
    tester,
  ) async {
    var downloads = 0;
    final cache = MessageMediaCache(
      store: _MemByteStore(),
      download: (_) async {
        downloads++;
        return downloads == 1 ? null : _pngBytes;
      },
    );

    await tester.pumpWidget(
      _host(
        message: _msg(
          type: 'image',
          mediaRef: 'ref-i',
          mediaUrl: 'https://cdn/i.jpg',
        ),
        cache: cache,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Imagen no disponible'), findsOneWidget);
    expect(downloads, 1);

    // El reintento explícito no espera el TTL anti-martilleo (30s).
    await tester.tap(find.byKey(const Key('message.image.m1.retry')));
    await tester.pumpAndSettle();

    expect(downloads, 2);
    expect(find.text('Imagen no disponible'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('las áreas de tap de imagen y video declaran Semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final cache = MessageMediaCache(
      store: _MemByteStore(),
      download: (_) async => _pngBytes,
    );
    await tester.pumpWidget(
      _host(
        message: _msg(
          type: 'image',
          mediaRef: 'ref-i',
          mediaUrl: 'https://cdn/i.jpg',
        ),
        cache: cache,
      ),
    );
    await tester.pumpAndSettle();
    // Precachea el decode (async real): sin tamaño pintado, el nodo de
    // semantics de la foto se podaría del árbol y el test sería flaky.
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(_pngBytes),
        tester.element(find.byType(MessageMediaContent)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Ver imagen'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        message: _msg(
          type: 'video',
          mediaRef: 'ref-v',
          mediaUrl: 'https://cdn/v.mp4',
        ),
        cache: cache,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Reproducir video'), findsOneWidget);
    semantics.dispose();
  });
}
