import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../data/cache/message_media_cache.dart';
import 'viewer_shell.dart';

/// Un adjunto de imagen dentro de una galería deslizable ([GalleryMediaItem]s
/// hermanos del mismo mensaje): identidad estable ([mediaRef]) para resolver
/// por caché, más la URL firmada de respaldo.
class GalleryMediaItem {
  const GalleryMediaItem({required this.mediaRef, this.url});

  final String mediaRef;
  final String? url;
}

/// Visor de imagen a pantalla completa sobre el cascarón compartido
/// ([ViewerShell]): zoom/paneo con [InteractiveViewer], cierre con el botón o
/// tocando el FONDO — un tap sobre la foto no cierra (tras hacer zoom, un
/// toque perdido no debe tirar el visor ni el estado de zoom).
///
/// Sirve [bytes] cacheados (offline / firma expirada) si los hay; si no, cae a
/// [url] (firma viva). Al menos uno debe venir.
///
/// Con [gallery] de más de un ítem, en cambio, abre un [PageView] deslizable
/// entre los adjuntos-imagen del mismo mensaje (cada página resuelve sus
/// propios bytes cache-first por ref, perezosamente al entrar en pantalla) con
/// un indicador de posición ("2/4"); [bytes]/[url] se ignoran en ese caso.
Future<void> showMediaViewer(
  BuildContext context, {
  Uint8List? bytes,
  String? url,
  List<GalleryMediaItem>? gallery,
  int initialIndex = 0,
}) {
  if (gallery != null && gallery.length > 1) {
    return showViewerRoute(
      context,
      builder: (_) =>
          _MediaGalleryViewer(items: gallery, initialIndex: initialIndex),
    );
  }
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

/// Galería deslizable entre los adjuntos-imagen de un mismo mensaje, sobre el
/// mismo [ViewerShell] (fondo, cierre, dismiss-en-el-fondo) que el visor de
/// una sola imagen. El indicador de posición vive DENTRO del contenido del
/// shell (no requiere tocar [ViewerShell]).
class _MediaGalleryViewer extends StatefulWidget {
  const _MediaGalleryViewer({required this.items, required this.initialIndex});

  final List<GalleryMediaItem> items;
  final int initialIndex;

  @override
  State<_MediaGalleryViewer> createState() => _MediaGalleryViewerState();
}

class _MediaGalleryViewerState extends State<_MediaGalleryViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _page = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewerShell(
      child: Stack(
        children: <Widget>[
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _GalleryPage(item: widget.items[i]),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(top: AppTokens.sp2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.sp3,
                    vertical: AppTokens.sp1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  ),
                  child: Text(
                    '${_page + 1}/${widget.items.length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una página de la galería: resuelve sus bytes cache-first por
/// [GalleryMediaItem.mediaRef] al entrar en pantalla (mismo patrón que
/// [AttachmentImage], perezoso — no descarga las N imágenes de golpe al abrir
/// la galería, sólo la visible).
class _GalleryPage extends StatefulWidget {
  const _GalleryPage({required this.item});

  final GalleryMediaItem item;

  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<_GalleryPage> {
  Uint8List? _bytes;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cache = context.read<MessageMediaCache>();
    final b = await cache.bytesFor(widget.item.mediaRef, widget.item.url);
    if (!mounted) return;
    setState(() {
      _bytes = b;
      _resolved = true;
    });
  }

  static const _broken = Icon(
    Icons.broken_image_outlined,
    size: 48,
    color: AppTokens.text2,
  );

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    if (b == null) {
      if (!_resolved) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
          ),
        );
      }
      return const Center(child: _broken);
    }
    return InteractiveViewer(
      maxScale: 5,
      child: Center(
        // Absorbe el tap sobre el contenido, igual que el visor de una sola
        // imagen: el dismiss del shell sólo aplica al fondo alrededor.
        child: GestureDetector(
          onTap: () {},
          child: Image.memory(
            b,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _broken,
          ),
        ),
      ),
    );
  }
}
