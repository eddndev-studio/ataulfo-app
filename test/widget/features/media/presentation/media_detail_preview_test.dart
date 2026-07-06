import 'dart:typed_data';
import 'dart:ui' as ui;

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

/// PNG real de [w]x[h] generado con el engine: el visor decodifica de verdad
/// (un fixture de bytes a mano no sobrevive al codec).
Future<Uint8List> _pngBytes(WidgetTester tester, int w, int h) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF336699),
    );
    final image = await recorder.endRecording().toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

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
        child: Scaffold(
          body: MediaDetailPage(
            loader: loader ?? _FakeLoader(Future<Uint8List?>.value(null)),
            launcher: launcher ?? _FakeLauncher(),
          ),
        ),
      ),
    ),
  ),
);

/// Tamaño pintado del lienzo del preview (la superficie redondeada que
/// enmarca el contenido).
Size _canvasSize(WidgetTester tester) =>
    tester.getSize(find.byKey(const Key('media_detail.preview_canvas')));

/// Monta [widget] con async REAL (el decode de imagen corre fuera del
/// fake-async del tester), espera a que el bitmap decodifique y pinta el
/// resultado.
Future<void> _pumpWithImage(WidgetTester tester, Widget widget) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(widget);
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
  await tester.pump();
}

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
      final png = await _pngBytes(tester, 8, 8);
      await _pumpWithImage(
        tester,
        _host(
          _asset(
            contentType: 'video/mp4',
            thumbnailUrl: 'https://x/poster.jpg',
          ),
          loader: _FakeLoader(Future<Uint8List?>.value(png)),
        ),
      );
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

  group('el lienzo abraza el contenido (no 300px fijos para todo)', () {
    testWidgets('audio: altura intrínseca del reproductor, sin mar vacío', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          _asset(contentType: 'audio/mpeg'),
          loader: _FakeLoader(Future<Uint8List?>.value(null)),
        ),
      );
      await tester.pump();

      expect(_canvasSize(tester).height, lessThan(200));
    });

    testWidgets('documento: tile compacto de ícono, no un lienzo de 300', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          _asset(contentType: 'application/pdf'),
          loader: _FakeLoader(Future<Uint8List?>.value(null)),
        ),
      );
      await tester.pump();

      expect(_canvasSize(tester).height, lessThan(250));
    });

    testWidgets('video sin poster: tile compacto con play superpuesto', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          _asset(contentType: 'video/mp4'),
          loader: _FakeLoader(Future<Uint8List?>.value(null)),
        ),
      );
      await tester.pump();

      expect(_canvasSize(tester).height, lessThan(250));
      expect(find.byKey(const Key('media_detail.play_video')), findsOneWidget);
    });

    testWidgets('imagen: el aspecto del bitmap dicta el lienzo '
        '(cuadrada ⇒ lienzo cuadrado al tope, no franja a lo ancho)', (
      tester,
    ) async {
      final png = await _pngBytes(tester, 8, 8);
      await _pumpWithImage(
        tester,
        _host(
          _asset(contentType: 'image/png', thumbnailUrl: 'https://x/t.png'),
          loader: _FakeLoader(Future<Uint8List?>.value(png)),
        ),
      );

      final size = _canvasSize(tester);
      // PNG cuadrado (aspecto 1): el lienzo es cuadrado, acotado al tope de
      // 300 — NO la franja full-width de 300 del layout viejo.
      expect(size.height, moreOrLessEquals(300));
      expect(size.width, moreOrLessEquals(size.height));
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
