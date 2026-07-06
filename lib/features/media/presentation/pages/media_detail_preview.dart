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

/// Bytes de una imagen junto con su relación de aspecto ya decodificada: el
/// lienzo del visor se dimensiona ANTES de pintar, con la forma real del bitmap.
typedef _DecodedImage = ({Uint8List bytes, double aspect});

/// Área de previsualización del detalle de un asset: imagen con zoom/pan,
/// video/audio reproducibles DENTRO de la misma pantalla (nunca el visor
/// externo del sistema), o el ícono del tipo para lo que no tiene reproductor
/// propio (documentos). Reusa la MISMA infraestructura de reproducción que ya
/// sirve a los hilos de chat ([VideoPlayback]/[MessageMediaCache]/
/// [AudioMessageContent]): el catálogo de media y los adjuntos de un mensaje
/// comparten un solo espacio de caché por `ref`.
///
/// El lienzo abraza el contenido en vez de imponer una caja fija: imagen y
/// poster de video toman la forma real del bitmap hasta [_maxViewerHeight]
/// (tope para no empujar la metadata fuera de vista; el zoom del
/// InteractiveViewer cubre el detalle fino), mientras audio y documento son
/// bloques a altura intrínseca — un reproductor de una línea o un ícono no
/// justifican un lienzo de 300px.
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
    return Align(
      child: ClipRRect(
        key: const Key('media_detail.preview_canvas'),
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: ColoredBox(color: AppTokens.surface2, child: _content()),
      ),
    );
  }

  Widget _content() {
    final ct = asset.contentType;
    if (ct.startsWith('video/')) {
      return _VideoPreview(asset: asset, loader: loader);
    }
    if (ct.startsWith('audio/')) return _AudioPreview(asset: asset);
    if (asset.thumbnailSourceUrl != null) {
      return _Image(asset: asset, loader: loader);
    }
    return _typeIconTile(asset);
  }
}

/// Alto máximo del lienzo de imagen/poster: acota para que el archivo y su
/// metadata se vean juntos; la forma dentro del tope la dicta el bitmap.
const double _maxViewerHeight = 300;

/// Tile compacto del tipo (documento, o media sin miniatura): presencia a
/// altura intrínseca, no un lienzo vacío.
Widget _typeIconTile(MediaAsset asset) => SizedBox(
  width: double.infinity,
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: AppTokens.sp7),
    child: Center(
      heightFactor: 1,
      child: Icon(
        mediaTypeIcon(asset.contentType),
        color: AppTokens.text2,
        size: 64,
      ),
    ),
  ),
);

/// Caja con la forma real del bitmap, acotada al tope del visor: el aspecto
/// decodificado dimensiona el lienzo (sin franjas muertas alrededor).
Widget _aspectBox({required double aspect, required Widget child}) =>
    ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _maxViewerHeight),
      child: AspectRatio(aspectRatio: aspect, child: child),
    );

/// Carga los bytes por el loader y decodifica su relación de aspecto. Null si
/// no hay bytes o el bitmap no decodifica (el caller cae al tile del tipo).
Future<_DecodedImage?> _decode(
  MediaThumbnailLoader loader,
  MediaAsset asset,
) async {
  final bytes = await loader.load(asset);
  if (bytes == null) return null;
  try {
    final image = await decodeImageFromList(bytes);
    final aspect = image.width / image.height;
    image.dispose();
    return (bytes: bytes, aspect: aspect);
  } catch (_) {
    return null;
  }
}

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

  late final Future<_DecodedImage?> _decoded = _decode(
    widget.loader,
    widget.asset,
  );
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
  Widget build(BuildContext context) => FutureBuilder<_DecodedImage?>(
    future: _decoded,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        // Placeholder al tope del visor: la imagen entrante suele llenarlo y
        // así el lienzo no salta hacia arriba al resolver.
        return const SizedBox(
          width: double.infinity,
          height: _maxViewerHeight,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
            ),
          ),
        );
      }
      final decoded = snapshot.data;
      if (decoded == null) return _typeIconTile(widget.asset);
      return _aspectBox(
        aspect: decoded.aspect,
        child: GestureDetector(
          onDoubleTapDown: _toggleZoom,
          child: InteractiveViewer(
            maxScale: 5,
            transformationController: _zoom,
            child: Image.memory(
              decoded.bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _typeIconTile(widget.asset),
            ),
          ),
        ),
      );
    },
  );
}

/// Previsualización de video: el poster derivado por el backend (si existe,
/// con el lienzo en su aspecto real) o el tile del tipo, con un botón de
/// reproducir superpuesto. Tocar resuelve la copia cacheada por
/// [MediaAsset.ref] (mismo espacio de caché que los adjuntos de chat) y abre
/// el reproductor DENTRO de la app — nunca el visor externo del sistema.
class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.asset, required this.loader});

  final MediaAsset asset;
  final MediaThumbnailLoader loader;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final Future<_DecodedImage?> _poster =
      widget.asset.thumbnailSourceUrl != null
      ? _decode(widget.loader, widget.asset)
      : Future<_DecodedImage?>.value(null);

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
          alignment: Alignment.center,
          children: <Widget>[
            FutureBuilder<_DecodedImage?>(
              future: _poster,
              builder: (context, snapshot) {
                final poster = snapshot.data;
                if (poster == null) return _typeIconTile(widget.asset);
                return _aspectBox(
                  aspect: poster.aspect,
                  child: Image.memory(
                    poster.bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _typeIconTile(widget.asset),
                  ),
                );
              },
            ),
            if (_resolving)
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
              )
            else
              Container(
                padding: const EdgeInsets.all(AppTokens.sp2),
                decoration: const BoxDecoration(
                  color: AppTokens.scrim,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: AppTokens.text1,
                  size: 40,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Previsualización de audio: reproductor inline (mismo widget que la burbuja
/// de nota de voz del hilo) a su altura intrínseca, cache-first por
/// [MediaAsset.ref].
class _AudioPreview extends StatelessWidget {
  const _AudioPreview({required this.asset});

  final MediaAsset asset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp4),
        child: AudioMessageContent(
          id: asset.ref,
          mediaRef: asset.ref,
          url: asset.previewUrl,
          ptt: false,
          contentType: asset.contentType,
        ),
      ),
    );
  }
}
