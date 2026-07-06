import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../media/domain/repositories/device_gallery_port.dart';
import '../../domain/attachment_intake.dart';
import 'attach_gallery_preview.dart';
import 'attach_gallery_tile.dart';

/// La previsualización del carrete embebida en la hoja de adjuntar: grilla de
/// miniaturas de las fotos/videos recientes con selección múltiple (badge
/// numerado en orden de tap, estilo WhatsApp) y el botón «Adjuntar (n)» que
/// confirma. Elegir assets del carrete es lo ÚNICO que hace: los bytes los
/// pide el composer después, bajo demanda. La miniatura ([GalleryTile]) y la
/// previsualización de mantener presionado viven en archivos hermanos.
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

  /// Tamaño de página del carrete: se enumeran los [limit] más recientes y
  /// scrollear cerca del final carga la siguiente página (scroll infinito).
  final int limit;

  /// Tope de selección: espeja el CUPO RESTANTE del lote de envío (tope del
  /// lote menos lo ya acumulado en la bandeja) para no ofrecer una selección
  /// que el composer recortaría igual.
  final int maxSelection;

  @override
  State<AttachGalleryPicker> createState() => _AttachGalleryPickerState();
}

class _AttachGalleryPickerState extends State<AttachGalleryPicker> {
  /// Assets acumulados página a página; `null` mientras la primera carga.
  List<DeviceMediaAsset>? _assets;

  /// Próxima página a pedir, si hay una carga en vuelo y si la última página
  /// vino corta (carrete agotado: no se pide más).
  int _nextPage = 0;
  bool _loadingPage = false;
  bool _exhausted = false;

  /// Selección en orden de tap; el índice+1 es el número del badge.
  final List<DeviceMediaAsset> _selection = <DeviceMediaAsset>[];

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_maybeLoadNextPage);
    unawaited(_loadNextPage());
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_maybeLoadNextPage);
    super.dispose();
  }

  /// Scroll cerca del final de la grilla ⇒ pide la siguiente página. El
  /// controller es el del sheet anfitrión, así que sólo mira su posición si
  /// existe (estados de carga/vacío también lo usan).
  void _maybeLoadNextPage() {
    if (_loadingPage || _exhausted || _assets == null) return;
    if (widget.scrollController.positions.length != 1) return;
    final position = widget.scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      unawaited(_loadNextPage());
    }
  }

  Future<void> _loadNextPage() async {
    if (_loadingPage || _exhausted) return;
    _loadingPage = true;
    final page = await widget.gallery.recentMedia(
      limit: widget.limit,
      page: _nextPage,
    );
    if (!mounted) return;
    setState(() {
      _loadingPage = false;
      _nextPage++;
      _exhausted = page.length < widget.limit;
      (_assets ??= <DeviceMediaAsset>[]).addAll(page);
    });
  }

  void _toggle(DeviceMediaAsset asset) {
    final index = _selection.indexWhere((a) => a.id == asset.id);
    if (index < 0 && _selection.length >= widget.maxSelection) {
      // El tope del lote: mismo aviso que el destino Documento, para que
      // tocar de más nunca sea un no-op invisible.
      unawaited(HapticFeedback.selectionClick());
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Máximo 10 archivos por envío')),
        );
      return;
    }
    setState(() {
      if (index >= 0) {
        _selection.removeAt(index);
      } else {
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
    final assets = _assets;
    final Widget body;
    if (assets == null) {
      body = _Scrollable(widget.scrollController);
    } else if (assets.isEmpty) {
      body = _Scrollable(
        widget.scrollController,
        child: Text(
          'Sin fotos recientes',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
        ),
      );
    } else {
      body = _grid(assets);
    }
    return Column(
      children: <Widget>[
        Expanded(child: body),
        if (_selection.isNotEmpty) _confirmBar(context),
      ],
    );
  }

  Widget _grid(List<DeviceMediaAsset> assets) {
    // Con una página en vuelo, una celda extra de spinner al final.
    final loadingCell = _loadingPage ? 1 : 0;
    return GridView.builder(
      key: const Key('attach_gallery.grid'),
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: assets.length + loadingCell,
      itemBuilder: (context, index) {
        if (index >= assets.length) {
          return const Center(
            key: Key('attach_gallery.loading_page'),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final asset = assets[index];
        return GalleryTile(
          key: Key('attach_gallery.item.${asset.id}'),
          asset: asset,
          gallery: widget.gallery,
          order: _orderOf(asset),
          onTap: () => _toggle(asset),
          onLongPress: () => unawaited(
            showGalleryAssetPreview(
              context,
              gallery: widget.gallery,
              asset: asset,
            ),
          ),
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
