import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';

/// Visor de imagen a pantalla completa: fondo negro, zoom/paneo con
/// [InteractiveViewer] y cierre con un tap (o el botón de cerrar). Ruta
/// transparente push-eada sobre el hilo — sin Scaffold propio, el fondo lo
/// pinta el contenedor.
///
/// Sirve [bytes] cacheados (offline / firma expirada) si los hay; si no, cae a
/// [url] (firma viva). Al menos uno debe venir.
Future<void> showMediaViewer(
  BuildContext context, {
  Uint8List? bytes,
  String? url,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (context, _, _) => _MediaViewer(bytes: bytes, url: url),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _MediaViewer extends StatelessWidget {
  const _MediaViewer({this.bytes, this.url});

  final Uint8List? bytes;
  final String? url;

  static const _broken = Icon(
    Icons.broken_image_outlined,
    size: 48,
    color: AppTokens.text2,
  );

  /// Prefiere los bytes cacheados (offline / firma expirada); si no, la URL viva.
  Widget _image() {
    final b = bytes;
    if (b != null) {
      return Image.memory(
        b,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _broken,
      );
    }
    final u = url;
    if (u == null) return _broken;
    return Image.network(
      u,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
          ),
        );
      },
      errorBuilder: (_, _, _) => _broken,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('media_viewer.dismiss'),
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        key: const Key('media_viewer'),
        color: Colors.black.withValues(alpha: 0.92),
        alignment: Alignment.center,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(child: _image()),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: IconButton(
                  key: const Key('media_viewer.close'),
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, color: AppTokens.text1),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
