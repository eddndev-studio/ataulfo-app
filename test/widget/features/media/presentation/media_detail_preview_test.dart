import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/repositories/media_preview_launcher.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/media/domain/repositories/media_thumbnail_loader.dart';
import 'package:ataulfo/features/media/presentation/bloc/media_detail_cubit.dart';
import 'package:ataulfo/features/media/presentation/pages/media_detail_page.dart';
import 'package:ataulfo/features/messages/data/cache/message_media_cache.dart';
import 'package:ataulfo/features/messages/presentation/bloc/thread_audio_cubit.dart';
import 'package:ataulfo/features/messages/presentation/widgets/audio_message_content.dart';
import 'package:ataulfo/features/messages/presentation/widgets/video_playback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_chat_media.dart';
import '../../../../support/fake_message_media_cache.dart';

class _MockRepo extends Mock implements MediaRepository {}

class _FakeLoader implements MediaThumbnailLoader {
  _FakeLoader(this._result);
  final Future<Uint8List?> _result;
  @override
  Future<Uint8List?> load(MediaAsset asset) => _result;
}

/// Launcher fake: registra qué URL se abrió. Video/audio NUNCA deben tocarlo.
class _FakeLauncher implements MediaPreviewLauncher {
  final List<String> opened = <String>[];
  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return true;
  }
}

/// Reproductor de video fake: registra con qué fuente se abrió.
class _FakeVideoPlayback implements VideoPlayback {
  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];

  @override
  Future<void> open(
    BuildContext context, {
    String? url,
    Uint8List? bytes,
    String? cacheKey,
  }) async {
    calls.add(<String, Object?>{
      'url': url,
      'bytes': bytes,
      'cacheKey': cacheKey,
    });
  }
}

final _png1x1 = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

MediaAsset _asset({
  required String contentType,
  String? previewUrl = 'https://x/sig',
  String? thumbnailUrl,
}) => MediaAsset(
  ref: 'tenant/orgA/media/clip',
  previewUrl: previewUrl,
  filename: 'clip',
  contentType: contentType,
  size: 4096,
  createdAt: DateTime.utc(2026, 6, 5, 14, 30),
  thumbnailUrl: thumbnailUrl,
);

Widget _host(
  MediaAsset asset, {
  MediaThumbnailLoader? loader,
  MediaPreviewLauncher? launcher,
  MessageMediaCache? cache,
  VideoPlayback? playback,
}) => MultiRepositoryProvider(
  providers: <RepositoryProvider<dynamic>>[
    RepositoryProvider<MessageMediaCache>.value(
      value: cache ?? fakeMessageMediaCache(),
    ),
    RepositoryProvider<VideoPlayback>.value(
      value: playback ?? _FakeVideoPlayback(),
    ),
  ],
  child: MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<ThreadAudioCubit>(
      create: (_) => ThreadAudioCubit(engine: const FakeAudioEngine()),
      child: BlocProvider<MediaDetailCubit>(
        create: (_) => MediaDetailCubit(repo: _MockRepo(), asset: asset),
        child: MediaDetailPage(
          loader: loader ?? _FakeLoader(Future<Uint8List?>.value(null)),
          launcher: launcher ?? _FakeLauncher(),
        ),
      ),
    ),
  ),
);

void main() {
  group('video: reproduce in-app, nunca url_launcher', () {
    testWidgets('sin poster: tocar el preview abre el reproductor in-app con '
        'la previewUrl', (tester) async {
      final playback = _FakeVideoPlayback();
      final launcher = _FakeLauncher();
      await tester.pumpWidget(
        _host(
          _asset(contentType: 'video/mp4'),
          loader: _FakeLoader(Future<Uint8List?>.value(null)),
          launcher: launcher,
          playback: playback,
        ),
      );
      await tester.pump();

      expect(find.text('Reproducir'), findsNothing); // ya no hay botón externo
      await tester.tap(find.byKey(const Key('media_detail.play_video')));
      await tester.pumpAndSettle();

      expect(playback.calls, hasLength(1));
      expect(playback.calls.single['url'], 'https://x/sig');
      expect(playback.calls.single['cacheKey'], 'tenant/orgA/media/clip');
      expect(launcher.opened, isEmpty);
    });

    testWidgets(
      'con bytes en caché por ref: el reproductor recibe esos bytes',
      (tester) async {
        final cache = fakeMessageMediaCache();
        await cache.cache(
          'tenant/orgA/media/clip',
          Uint8List.fromList(<int>[1, 2, 3]),
        );
        final playback = _FakeVideoPlayback();
        await tester.pumpWidget(
          _host(
            _asset(contentType: 'video/mp4'),
            loader: _FakeLoader(Future<Uint8List?>.value(null)),
            cache: cache,
            playback: playback,
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('media_detail.play_video')));
        await tester.pumpAndSettle();

        expect(
          playback.calls.single['bytes'],
          Uint8List.fromList(<int>[1, 2, 3]),
        );
      },
    );

    testWidgets('sin caché y sin previewUrl: avisa en vez de abrir el '
        'reproductor', (tester) async {
      final playback = _FakeVideoPlayback();
      await tester.pumpWidget(
        _host(
          _asset(contentType: 'video/mp4', previewUrl: null),
          loader: _FakeLoader(Future<Uint8List?>.value(null)),
          playback: playback,
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('media_detail.play_video')));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo reproducir el video'), findsOneWidget);
      expect(playback.calls, isEmpty);
    });

    testWidgets('con poster derivado: el preview pinta el poster, no sólo el '
        'ícono', (tester) async {
      await tester.pumpWidget(
        _host(
          _asset(
            contentType: 'video/mp4',
            thumbnailUrl: 'https://x/poster.jpg',
          ),
          loader: _FakeLoader(Future<Uint8List?>.value(_png1x1)),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('audio: reproductor inline, nunca url_launcher', () {
    testWidgets('pinta AudioMessageContent inline y no ofrece abrir externo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          _asset(contentType: 'audio/mpeg'),
          loader: _FakeLoader(Future<Uint8List?>.value(null)),
        ),
      );
      await tester.pump();

      expect(find.byType(AudioMessageContent), findsOneWidget);
      expect(find.text('Reproducir'), findsNothing);
      expect(find.text('Abrir'), findsNothing);
    });

    testWidgets('tocar el toggle reproduce por el ref BARE del asset', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          _asset(contentType: 'audio/mpeg'),
          loader: _FakeLoader(Future<Uint8List?>.value(null)),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('message.audio.tenant/orgA/media/clip.toggle')),
      );
      await tester.pump();

      final cubit = _findAudioCubit(tester);
      expect(cubit.state.sourceKey, 'tenant/orgA/media/clip');
    });
  });

  testWidgets('documento sigue ofreciendo Abrir vía el visor externo', (
    tester,
  ) async {
    final launcher = _FakeLauncher();
    await tester.pumpWidget(
      _host(
        _asset(contentType: 'application/pdf'),
        loader: _FakeLoader(Future<Uint8List?>.value(null)),
        launcher: launcher,
      ),
    );
    await tester.pump();

    expect(find.text('Abrir'), findsOneWidget);
    await tester.tap(find.text('Abrir'));
    await tester.pump();
    expect(launcher.opened, <String>['https://x/sig']);
  });
}

/// Lee el [ThreadAudioCubit] montado por [_host] desde el árbol actual.
ThreadAudioCubit _findAudioCubit(WidgetTester tester) {
  return tester.element(find.byType(MediaDetailPage)).read<ThreadAudioCubit>();
}
