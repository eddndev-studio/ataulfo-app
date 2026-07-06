import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../messages/data/cache/message_media_cache.dart';
import '../../../messages/presentation/widgets/audio_message_content.dart';
import '../../../messages/presentation/widgets/video_playback.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/repositories/media_thumbnail_loader.dart';
import '../media_format.dart';

/// Área de previsualización del detalle de un asset: imagen con zoom/pan,
/// video/audio reproducibles DENTRO de la misma pantalla (nunca el visor
/// externo del sistema), o el ícono del tipo para lo que no tiene reproductor
/// propio (documentos). Reusa la MISMA infraestructura de reproducción que ya
/// sirve a los hilos de chat ([VideoPlayback]/[MessageMediaCache]/
/// [AudioMessageContent]): el catálogo de media y los adjuntos de un mensaje
/// comparten un solo espacio de caché por `ref`.
class MediaDetailPreview extends StatelessWidget {
  const MediaDetailPreview({
    super.key,
    required this.asset,
    required this.loader,
  });

  final MediaAsset asset;
  final MediaThumbnailLoader loader;

  @override
  Widget build(BuildContext context) {
    // Altura acotada (no AspectRatio a ancho completo, que en pantallas altas
    // empujaría la metadata fuera de vista): un visor contenido deja ver el
    // archivo y la metadata juntos. El zoom del InteractiveViewer cubre el
    // detalle fino de las imágenes.
    return SizedBox(
      height: 300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: Container(
          color: AppTokens.surface2,
          alignment: Alignment.center,
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    final ct = asset.contentType;
    if (ct.startsWith('video/')) {
      return _VideoPreview(asset: asset, loader: loader);
    }
    if (ct.startsWith('audio/')) return _AudioPreview(asset: asset);
    if (asset.thumbnailSourceUrl != null)
      return _Image(asset: asset, loader: loader);
    return _typeIcon(asset);
  }
}

Widget _typeIcon(MediaAsset asset) =>
    Icon(mediaTypeIcon(asset.contentType), color: AppTokens.text2, size: 64);

/// Previsualización de imagen con zoom/pan (doble-tap alterna 1x ⇄ acercado).
class _Image extends StatefulWidget {
  const _Image({required this.asset, required this.loader});

  final MediaAsset asset;
  final MediaThumbnailLoader loader;

  @override
  State<_Image> createState() => _ImageState();
}

class _ImageState extends State<_Image> {
  /// Escala del doble-tap: suficiente para leer detalle fino sin perderse; el
  /// pinch cubre el rango completo hasta el maxScale del InteractiveViewer.
  static const double _doubleTapScale = 2.5;

  late final Future<Uint8List?> _bytes = widget.loader.load(widget.asset);
  final TransformationController _zoom = TransformationController();

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  /// Doble tap: alterna entre 1x y [_doubleTapScale] centrado en el punto
  /// tocado (acercar donde se miró, no la esquina superior izquierda).
  void _toggleZoom(TapDownDetails details) {
    if (_zoom.value.getMaxScaleOnAxis() > 1.01) {
      _zoom.value = Matrix4.identity();
      return;
    }
    final p = details.localPosition;
    _zoom.value = Matrix4.identity()
      ..translateByDouble(
        -p.dx * (_doubleTapScale - 1),
        -p.dy * (_doubleTapScale - 1),
        0,
        1,
      )
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, _doubleTapScale, 1);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTokens.text2),
        );
      }
      final bytes = snapshot.data;
      if (bytes == null) return _typeIcon(widget.asset);
      return GestureDetector(
        onDoubleTapDown: _toggleZoom,
        child: InteractiveViewer(
          maxScale: 5,
          transformationController: _zoom,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _typeIcon(widget.asset),
          ),
        ),
      );
    },
  );
}

/// Previsualización de video: el poster derivado por el backend (si existe) o
/// el ícono del tipo, con un botón de reproducir superpuesto. Tocar resuelve
/// la copia cacheada por [MediaAsset.ref] (mismo espacio de caché que los
/// adjuntos de chat) y abre el reproductor DENTRO de la app — nunca el visor
/// externo del sistema.
class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.asset, required this.loader});

  final MediaAsset asset;
  final MediaThumbnailLoader loader;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final Future<Uint8List?> _poster =
      widget.asset.thumbnailSourceUrl != null
      ? widget.loader.load(widget.asset)
      : Future<Uint8List?>.value(null);

  /// Resolviendo bytes (descarga de un video aún sin caché): spinner sobre el
  /// play en vez de un toque muerto.
  bool _resolving = false;

  Future<void> _play() async {
    if (_resolving) return;
    final asset = widget.asset;
    final playback = context.read<VideoPlayback>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _resolving = true);
    Uint8List? bytes;
    try {
      bytes = await context.read<MessageMediaCache>().bytesFor(
        asset.ref,
        asset.previewUrl,
      );
    } catch (_) {
      bytes = null;
    }
    if (!mounted) return;
    setState(() => _resolving = false);
    if (bytes == null && asset.previewUrl == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No se pudo reproducir el video')),
        );
      return;
    }
    if (!mounted) return;
    await playback.open(
      context,
      url: asset.previewUrl,
      bytes: bytes,
      cacheKey: asset.ref,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Reproducir video',
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('media_detail.play_video'),
        behavior: HitTestBehavior.opaque,
        onTap: _play,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            FutureBuilder<Uint8List?>(
              future: _poster,
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes == null) return _typeIcon(widget.asset);
                return Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => _typeIcon(widget.asset),
                );
              },
            ),
            Center(
              child: _resolving
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTokens.primary,
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(AppTokens.sp2),
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Previsualización de audio: reproductor inline (mismo widget que la burbuja
/// de nota de voz del hilo), cache-first por [MediaAsset.ref].
class _AudioPreview extends StatelessWidget {
  const _AudioPreview({required this.asset});

  final MediaAsset asset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.sp4),
      child: AudioMessageContent(
        id: asset.ref,
        mediaRef: asset.ref,
        url: asset.previewUrl,
        ptt: false,
        contentType: asset.contentType,
      ),
    );
  }
}
