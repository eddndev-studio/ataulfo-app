import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../media/domain/repositories/device_gallery_port.dart';
import '../../domain/attachment_intake.dart';

/// La previsualización del carrete embebida en la hoja de adjuntar: grilla de
/// miniaturas de las fotos/videos recientes con selección múltiple (badge
/// numerado en orden de tap, estilo WhatsApp) y el botón «Adjuntar (n)» que
/// confirma. Elegir assets del carrete es lo ÚNICO que hace: los bytes los
/// pide el composer después, bajo demanda.
///
/// La grilla usa el [scrollController] que entrega el
/// `DraggableScrollableSheet` anfitrión: así arrastrarla acopla scroll y
/// altura de la hoja (la grilla crece in-place). Estados de carga/vacío
/// también son scrolleables con ese controller para que el gesto de arrastre
/// funcione desde el primer frame.
class AttachGalleryPicker extends StatefulWidget {
  const AttachGalleryPicker({
    super.key,
    required this.gallery,
    required this.scrollController,
    required this.onConfirm,
    this.limit = 120,
    this.maxSelection = kMaxAttachmentsPerBatch,
  });

  final DeviceGalleryPort gallery;
  final ScrollController scrollController;

  /// Recibe la selección confirmada, en orden de tap.
  final void Function(List<DeviceMediaAsset> assets) onConfirm;

  /// Cuántos recientes enumerar (una sola página del carrete).
  final int limit;

  /// Tope de selección: espeja el tope del lote de envío para no ofrecer
  /// una selección que el composer recortaría igual.
  final int maxSelection;

  @override
  State<AttachGalleryPicker> createState() => _AttachGalleryPickerState();
}

class _AttachGalleryPickerState extends State<AttachGalleryPicker> {
  /// Enumeración única por apertura del sheet (no se re-lista en cada
  /// rebuild de la selección).
  late final Future<List<DeviceMediaAsset>> _recent = widget.gallery
      .recentMedia(limit: widget.limit);

  /// Selección en orden de tap; el índice+1 es el número del badge.
  final List<DeviceMediaAsset> _selection = <DeviceMediaAsset>[];

  void _toggle(DeviceMediaAsset asset) {
    setState(() {
      final index = _selection.indexWhere((a) => a.id == asset.id);
      if (index >= 0) {
        _selection.removeAt(index);
      } else if (_selection.length < widget.maxSelection) {
        _selection.add(asset);
      }
    });
  }

  int? _orderOf(DeviceMediaAsset asset) {
    final index = _selection.indexWhere((a) => a.id == asset.id);
    return index >= 0 ? index + 1 : null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: FutureBuilder<List<DeviceMediaAsset>>(
            future: _recent,
            builder: (context, snapshot) {
              final assets = snapshot.data;
              if (assets == null) return _Scrollable(widget.scrollController);
              if (assets.isEmpty) {
                return _Scrollable(
                  widget.scrollController,
                  child: Text(
                    'Sin fotos recientes',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
                  ),
                );
              }
              return _grid(assets);
            },
          ),
        ),
        if (_selection.isNotEmpty) _confirmBar(context),
      ],
    );
  }

  Widget _grid(List<DeviceMediaAsset> assets) {
    return GridView.builder(
      key: const Key('attach_gallery.grid'),
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        final asset = assets[index];
        return _GalleryTile(
          key: Key('attach_gallery.item.${asset.id}'),
          asset: asset,
          gallery: widget.gallery,
          order: _orderOf(asset),
          onTap: () => _toggle(asset),
        );
      },
    );
  }

  Widget _confirmBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp4,
        AppTokens.sp2,
        AppTokens.sp4,
        AppTokens.sp2 + context.sheetBottomInset,
      ),
      child: AppButton.filled(
        key: const Key('attach_gallery.confirm'),
        label: 'Adjuntar (${_selection.length})',
        fullWidth: true,
        onPressed: () =>
            widget.onConfirm(List<DeviceMediaAsset>.of(_selection)),
      ),
    );
  }
}

/// Cascarón scrolleable para carga/vacío: mantiene el controller del sheet
/// activo (la hoja sigue siendo arrastrable) aunque no haya grilla aún.
class _Scrollable extends StatelessWidget {
  const _Scrollable(this.controller, {this.child});

  final ScrollController controller;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppTokens.sp6),
          child: child ?? const Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

/// Una miniatura del carrete: imagen cuadrada (o placeholder si la miniatura
/// no se pudo generar), overlay de duración para videos y badge numerado
/// cuando está seleccionada. Tocar alterna la selección.
class _GalleryTile extends StatefulWidget {
  const _GalleryTile({
    super.key,
    required this.asset,
    required this.gallery,
    required this.order,
    required this.onTap,
  });

  final DeviceMediaAsset asset;
  final DeviceGalleryPort gallery;

  /// Posición 1-based en la selección, o `null` si no está seleccionada.
  final int? order;
  final VoidCallback onTap;

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  /// Miniatura pedida UNA vez por tile (no en cada rebuild de selección).
  late final Future<Uint8List?> _thumb = widget.gallery.thumbnailFor(
    widget.asset,
    size: 256,
  );

  @override
  Widget build(BuildContext context) {
    final selected = widget.order != null;
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
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
              child: _VideoBadge(durationMs: widget.asset.durationMs),
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
      ),
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
class _VideoBadge extends StatelessWidget {
  const _VideoBadge({required this.durationMs});

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
              _formatDuration(ms),
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
String _formatDuration(int ms) {
  String two(int n) => n.toString().padLeft(2, '0');
  final total = ms ~/ 1000;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
  return '$minutes:${two(seconds)}';
}
