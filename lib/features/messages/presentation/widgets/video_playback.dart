import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'video_player_screen.dart';
import 'viewer_shell.dart';

/// Servicio de presentación para reproducir un video del hilo DENTRO de la app
/// (no delega al reproductor del sistema). Se inyecta para que la burbuja de
/// video sea testeable sin tocar el plugin de reproducción.
abstract interface class VideoPlayback {
  /// Abre el reproductor a pantalla completa. [bytes] es la copia local
  /// cacheada (fuente preferida: sirve offline y con la firma caída) y
  /// [cacheKey] su identidad estable (el `mediaRef`); [url] es el respaldo de
  /// streaming (URL firmada). Al menos una fuente debe venir.
  Future<void> open(
    BuildContext context, {
    String? url,
    Uint8List? bytes,
    String? cacheKey,
  });
}

/// Empuja el reproductor a pantalla completa [VideoPlayerScreen] sobre el hilo.
class InAppVideoPlayback implements VideoPlayback {
  const InAppVideoPlayback();

  @override
  Future<void> open(
    BuildContext context, {
    String? url,
    Uint8List? bytes,
    String? cacheKey,
  }) {
    assert(url != null || bytes != null, 'sin fuente de video');
    // Misma ruta transparente con fade que el visor de imagen: una sola
    // manera de entrar y salir de "ver media en grande".
    return showViewerRoute(
      context,
      builder: (_) =>
          VideoPlayerScreen(url: url, bytes: bytes, cacheKey: cacheKey),
    );
  }
}
