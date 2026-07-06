import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/design/tokens.dart';
import 'viewer_shell.dart';

/// Reproductor de video a pantalla completa: fondo negro, controles mínimos
/// (play/pausa + barra de progreso con scrubbing) y cierre. Prefiere la copia
/// local en [bytes] (cacheada por `mediaRef`: sirve offline y con la firma
/// caída, materializada a un archivo temporal — el plugin no reproduce desde
/// memoria); sin bytes streamea la [url] firmada.
///
/// La inicialización va en un try/catch: en una plataforma sin implementación
/// del plugin (p. ej. Linux desktop) o ante una URL inválida cae a un estado de
/// error legible en vez de romper. No hay verificación E2E aquí — un dispositivo
/// real confirma la reproducción.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    this.url,
    this.bytes,
    this.cacheKey,
    this.cacheDir,
    super.key,
  }) : assert(url != null || bytes != null, 'sin fuente de video');

  final String? url;
  final Uint8List? bytes;

  /// Identidad estable de [bytes] (el `mediaRef`, inmutable): nombra el archivo
  /// temporal para que re-abrir el mismo video reuse la copia ya escrita.
  final String? cacheKey;

  /// Directorio para materializar [bytes] a archivo (inyectable en tests);
  /// por defecto la caché temporal de la app.
  final Future<Directory> Function()? cacheDir;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Materializa los bytes cacheados a un archivo temporal (nombrado por
  /// [VideoPlayerScreen.cacheKey] saneado; los refs son inmutables, así que un
  /// archivo existente con el tamaño esperado se reusa sin reescribir).
  Future<VideoPlayerController> _fileController(Uint8List bytes) async {
    final dir = await (widget.cacheDir ?? getTemporaryDirectory)();
    final raw = widget.cacheKey ?? 'video';
    final name = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      '${dir.path}${Platform.pathSeparator}ataulfo_media'
      '${Platform.pathSeparator}$name.mp4',
    );
    if (!file.existsSync() || file.lengthSync() != bytes.length) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    }
    return VideoPlayerController.file(file);
  }

  Future<void> _init() async {
    VideoPlayerController? c;
    try {
      final bytes = widget.bytes;
      c = bytes != null
          ? await _fileController(bytes)
          : VideoPlayerController.networkUrl(Uri.parse(widget.url!));
      await c.initialize();
      if (!mounted) {
        unawaited(c.dispose());
        return;
      }
      // Asigna el controlador ANTES de reproducir: si el widget se desmonta
      // durante estos awaits, `dispose()` ya lo alcanza y lo libera.
      setState(() => _controller = c);
      await c.setLooping(false);
      await c.play();
    } catch (_) {
      // Un init fallido deja recursos del plugin ya reservados: si el fallo
      // ocurrió antes de asignarlo, hay que liberarlo aquí (dispose() no lo
      // alcanzaría); si ya se asignó, dispose() se encarga.
      if (_controller == null) unawaited(c?.dispose());
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
  }

  @override
  Widget build(BuildContext context) {
    // Cascarón compartido con el visor de imagen: mismo fondo, mismo botón de
    // cerrar y mismo tap-en-el-fondo para descartar. La superficie del video
    // absorbe su propio tap (play/pausa), así que no cierra por accidente.
    return ViewerShell(
      backgroundKey: const Key('video_player'),
      dismissKey: const Key('video_player.dismiss'),
      closeKey: const Key('video_player.close'),
      child: Center(child: _content()),
    );
  }

  Widget _content() {
    if (_failed) {
      return Column(
        key: const Key('video_player.failed'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.videocam_off_outlined,
            size: 48,
            color: AppTokens.text2,
          ),
          const SizedBox(height: AppTokens.sp3),
          Text(
            'No se pudo reproducir el video',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTokens.text2),
          ),
        ],
      );
    }
    final c = _controller;
    if (c == null) {
      return const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
      );
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (context, value, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: GestureDetector(
              key: const Key('video_player.surface'),
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    VideoPlayer(c),
                    if (!value.isPlaying)
                      const Icon(
                        Icons.play_circle_fill,
                        size: 72,
                        color: Colors.white70,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTokens.sp2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp4),
            child: VideoProgressIndicator(
              c,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppTokens.chatAccent,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.sp4),
        ],
      ),
    );
  }
}
