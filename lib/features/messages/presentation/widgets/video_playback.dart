import 'package:flutter/material.dart';

import 'video_player_screen.dart';

/// Servicio de presentación para reproducir un video del hilo DENTRO de la app
/// (no delega al reproductor del sistema). Se inyecta para que la burbuja de
/// video sea testeable sin tocar el plugin de reproducción.
abstract interface class VideoPlayback {
  /// Abre el reproductor a pantalla completa para [url] (URL firmada).
  Future<void> open(BuildContext context, {required String url});
}

/// Empuja el reproductor a pantalla completa [VideoPlayerScreen] sobre el hilo.
class InAppVideoPlayback implements VideoPlayback {
  const InAppVideoPlayback();

  @override
  Future<void> open(BuildContext context, {required String url}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => VideoPlayerScreen(url: url),
      ),
    );
  }
}
