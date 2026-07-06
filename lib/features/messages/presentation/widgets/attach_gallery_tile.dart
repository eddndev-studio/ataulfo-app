import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../media/domain/repositories/device_gallery_port.dart';

/// Una miniatura del carrete: imagen cuadrada (o placeholder si la miniatura
/// no se pudo generar), overlay de duración para videos y badge numerado
/// cuando está seleccionada. Tocar alterna la selección; mantener presionado
/// abre la previsualización ([onLongPress]).
class GalleryTile extends StatefulWidget {
  const GalleryTile({
    super.key,
    required this.asset,
    required this.gallery,
    required this.order,
    required this.onTap,
    this.onLongPress,
  });

  final DeviceMediaAsset asset;
  final DeviceGalleryPort gallery;

  /// Posición 1-based en la selección, o `null` si no está seleccionada.
  final int? order;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<GalleryTile> {
  /// Miniatura pedida UNA vez por tile (no en cada rebuild de selección).
  late final Future<Uint8List?> _thumb = widget.gallery.thumbnailFor(
    widget.asset,
    size: 256,
  );

  @override
  Widget build(BuildContext context) {
    final selected = widget.order != null;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${widget.asset.isVideo ? 'Video' : 'Foto'} ${widget.asset.filename}',
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: _body(context, selected),
      ),
    );
  }

  Widget _body(BuildContext context, bool selected) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        FutureBuilder<Uint8List?>(
          future: _thumb,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) return _placeholder();
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _placeholder(),
            );
          },
        ),
        if (widget.asset.isVideo)
          Positioned(
            left: AppTokens.sp1,
            bottom: AppTokens.sp1,
            child: GalleryVideoBadge(durationMs: widget.asset.durationMs),
          ),
        if (selected)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                border: Border.all(color: AppTokens.primary, width: 2),
              ),
            ),
          ),
        if (selected)
          Positioned(
            top: AppTokens.sp1,
            right: AppTokens.sp1,
            child: Container(
              key: Key('attach_gallery.check.${widget.asset.id}'),
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppTokens.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${widget.order}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTokens.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeholder() => Container(
    color: AppTokens.surface3,
    child: Icon(
      widget.asset.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
      color: AppTokens.text2,
    ),
  );
}

/// Señal de video sobre la miniatura: ícono + duración legible (m:ss).
class GalleryVideoBadge extends StatelessWidget {
  const GalleryVideoBadge({super.key, required this.durationMs});

  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    final ms = durationMs;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.videocam, size: 12, color: AppTokens.text1),
          if (ms != null) ...<Widget>[
            const SizedBox(width: 2),
            Text(
              formatGalleryDuration(ms),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppTokens.text1),
            ),
          ],
        ],
      ),
    );
  }
}

/// `m:ss` (o `h:mm:ss` para clips largos), estilo carrete.
String formatGalleryDuration(int ms) {
  String two(int n) => n.toString().padLeft(2, '0');
  final total = ms ~/ 1000;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
  return '$minutes:${two(seconds)}';
}
