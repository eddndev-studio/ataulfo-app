import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import 'viewer_shell.dart';

/// Visor de imagen a pantalla completa sobre el cascarón compartido
/// ([ViewerShell]): zoom/paneo con [InteractiveViewer], cierre con el botón o
/// tocando el FONDO — un tap sobre la foto no cierra (tras hacer zoom, un
/// toque perdido no debe tirar el visor ni el estado de zoom).
///
/// Sirve [bytes] cacheados (offline / firma expirada) si los hay; si no, cae a
/// [url] (firma viva). Al menos uno debe venir.
Future<void> showMediaViewer(
  BuildContext context, {
  Uint8List? bytes,
  String? url,
}) {
  return showViewerRoute(
    context,
    builder: (_) => _MediaViewer(bytes: bytes, url: url),
  );
}

class _MediaViewer extends StatefulWidget {
  const _MediaViewer({this.bytes, this.url});

  final Uint8List? bytes;
  final String? url;

  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer> {
  /// Generación del reintento: re-monta el Image.network fallido (los fallos
  /// de red no se quedan en el ImageCache, así que un widget nuevo re-dispara
  /// la carga de verdad).
  int _attempt = 0;

  static const _broken = Icon(
    Icons.broken_image_outlined,
    size: 48,
    color: AppTokens.text2,
  );

  /// Prefiere los bytes cacheados (offline / firma expirada); si no, la URL viva.
  Widget _image() {
    final b = widget.bytes;
    if (b != null) {
      return Image.memory(
        b,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _broken,
      );
    }
    final u = widget.url;
    if (u == null) return _broken;
    return Image.network(
      u,
      key: ValueKey<int>(_attempt),
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
          ),
        );
      },
      // Fallo de descarga (offline / firma caída): reintento manual en vez de
      // esperar a que el widget se recicle.
      errorBuilder: (_, _, _) => Padding(
        padding: const EdgeInsets.all(AppTokens.sp5),
        child: AppErrorState(
          message: 'No pudimos cargar la imagen',
          onRetry: () => setState(() => _attempt++),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ViewerShell(
      child: InteractiveViewer(
        maxScale: 5,
        child: Center(
          // Absorbe el tap sobre el contenido: el gesto de descarte del shell
          // sólo aplica al fondo alrededor.
          child: GestureDetector(onTap: () {}, child: _image()),
        ),
      ),
    );
  }
}
