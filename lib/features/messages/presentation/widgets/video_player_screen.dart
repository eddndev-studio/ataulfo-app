import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/design/tokens.dart';

/// Reproductor de video a pantalla completa: fondo negro, controles mínimos
/// (play/pausa + barra de progreso con scrubbing) y cierre. Reproduce desde la
/// URL firmada por streaming.
///
/// La inicialización va en un try/catch: en una plataforma sin implementación
/// del plugin (p. ej. Linux desktop) o ante una URL inválida cae a un estado de
/// error legible en vez de romper. No hay verificación E2E aquí — un dispositivo
/// real confirma la reproducción.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({required this.url, super.key});

  final String url;

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

  Future<void> _init() async {
    VideoPlayerController? c;
    try {
      c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: Center(child: _content())),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                key: const Key('video_player.close'),
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close, color: AppTokens.text1),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
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
