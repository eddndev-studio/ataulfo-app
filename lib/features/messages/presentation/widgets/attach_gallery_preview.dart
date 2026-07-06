import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../media/domain/repositories/device_gallery_port.dart';
import 'attach_gallery_tile.dart';

/// Previsualización de SOLO LECTURA de un asset del carrete (mantener
/// presionada su miniatura): la imagen ampliada —o el fotograma del video con
/// su duración— antes de comprometerse a seleccionarlo. Tocar en cualquier
/// parte la cierra; no altera la selección ni pide los bytes completos (usa
/// una miniatura grande, no `bytesFor`).
Future<void> showGalleryAssetPreview(
  BuildContext context, {
  required DeviceGalleryPort gallery,
  required DeviceMediaAsset asset,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Dialog(
        key: const Key('attach_gallery.preview'),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppTokens.sp4),
        child: _PreviewBody(gallery: gallery, asset: asset),
      ),
    ),
  );
}

/// Cuerpo de la previsualización: miniatura GRANDE bajo demanda (1024 px) con
/// la señal de video superpuesta. Mientras carga, un spinner; si no se pudo
/// generar, el mismo placeholder de la grilla en grande.
class _PreviewBody extends StatefulWidget {
  const _PreviewBody({required this.gallery, required this.asset});

  final DeviceGalleryPort gallery;
  final DeviceMediaAsset asset;

  @override
  State<_PreviewBody> createState() => _PreviewBodyState();
}

class _PreviewBodyState extends State<_PreviewBody> {
  late final Future<Uint8List?> _large = widget.gallery.thumbnailFor(
    widget.asset,
    size: 1024,
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          FutureBuilder<Uint8List?>(
            future: _large,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final bytes = snapshot.data;
              if (bytes == null) return _placeholder();
              return Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _placeholder(),
              );
            },
          ),
          if (widget.asset.isVideo)
            Positioned(
              left: AppTokens.sp2,
              bottom: AppTokens.sp2,
              child: GalleryVideoBadge(durationMs: widget.asset.durationMs),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 240,
    color: AppTokens.surface3,
    alignment: Alignment.center,
    child: Icon(
      widget.asset.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
      size: AppTokens.sp8,
      color: AppTokens.text2,
    ),
  );
}
