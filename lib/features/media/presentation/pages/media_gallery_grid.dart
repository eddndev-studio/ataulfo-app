import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_page_container.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/repositories/media_thumbnail_loader.dart';
import '../bloc/media_gallery_bloc.dart';
import '../widgets/media_thumbnail.dart';

/// Grid de miniaturas de la galería de media. Resuelve el GESTO por modo:
/// browse (tap = detalle, long-press = selección-para-borrar), picker single
/// (tap = elegir, long-press = preview) y multi-picker (tap = alternar la
/// selección local, long-press = preview).
class MediaGalleryGrid extends StatelessWidget {
  const MediaGalleryGrid({
    super.key,
    required this.controller,
    required this.state,
    required this.onSelect,
    required this.onOpenDetail,
    required this.loader,
    this.pickedRefs = const <String>{},
    this.onTogglePick,
  });

  final ScrollController controller;
  final MediaGalleryLoaded state;
  final ValueChanged<MediaAsset>? onSelect;
  final Future<bool> Function(MediaAsset asset)? onOpenDetail;
  final MediaThumbnailLoader loader;

  /// Refs marcados por el multi-picker (selección local de la página).
  final Set<String> pickedRefs;

  /// Alterna la selección local del multi-picker; null ⇒ no hay multi.
  final ValueChanged<MediaAsset>? onTogglePick;

  @override
  Widget build(BuildContext context) {
    final items = state.items;
    // Una fila extra para el indicador de paginación cuando hay una página en
    // vuelo; así el spinner viaja al final del grid sin desplazar las celdas.
    final showFooter = state.isLoadingMore;
    return GridView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppPageGutters.primary,
        AppTokens.sp4,
        AppPageGutters.primary,
        // Deja aire para que el FAB no tape la última fila.
        AppTokens.sp9 + context.safeBottomInset,
      ),
      // Columnas según el ancho disponible (no 3 fijas): en móvil da ~3, en
      // desktop ancho llena con más sin estirar las celdas. El extent acota el
      // tamaño máximo de cada miniatura; las celdas son cuadradas (el caption
      // del displayName flota dentro, no añade alto).
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: AppTokens.sp3,
        crossAxisSpacing: AppTokens.sp3,
      ),
      itemCount: items.length + (showFooter ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          return const Center(
            key: Key('media_gallery.load_more_indicator'),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
              ),
            ),
          );
        }
        final MediaAsset asset = items[i];
        // Browse: long-press entra/alterna la selección-para-borrar del bloc
        // (en modo selección el tap también alterna). Pickers (single o
        // multi): el long-press es PREVIEW del detalle — ver en grande antes
        // de elegir — y el tap elige (single) o alterna la selección local
        // (multi).
        final isBrowse = onSelect == null && onTogglePick == null;
        final VoidCallback? onLongPress = isBrowse
            ? () => context.read<MediaGalleryBloc>().add(
                MediaGallerySelectionToggled(asset.ref),
              )
            : _previewHandler(context, asset);
        return MediaThumbnail(
          asset: asset,
          loader: loader,
          selected:
              state.selectedRefs.contains(asset.ref) ||
              pickedRefs.contains(asset.ref),
          onLongPress: onLongPress,
          onTap: (isBrowse && state.selectionMode)
              ? onLongPress
              : _tapHandler(context, asset),
        );
      },
    );
  }

  /// Gesto del tap según el modo. Multi-picker ([onTogglePick]): alterna la
  /// selección local. Picker single ([onSelect]): selecciona (el consumidor
  /// usa `asset.ref` BARE, nunca persiste la previewUrl). Browse
  /// ([onOpenDetail]): abre el detalle. Sin ninguno ⇒ tap inerte (sólo visor).
  VoidCallback? _tapHandler(BuildContext context, MediaAsset asset) {
    if (onTogglePick != null) return () => onTogglePick!(asset);
    if (onSelect != null) return () => onSelect!(asset);
    return _previewHandler(context, asset);
  }

  /// Abre el detalle y, si reportó un cambio (borrado/renombrado), refresca la
  /// galería. El `context` aquí está bajo el [MediaGalleryBloc], así que puede
  /// despachar el refresh.
  VoidCallback? _previewHandler(BuildContext context, MediaAsset asset) {
    final open = onOpenDetail;
    if (open == null) return null;
    return () async {
      final changed = await open(asset);
      if (changed && context.mounted) {
        context.read<MediaGalleryBloc>().add(
          const MediaGalleryRefreshRequested(),
        );
      }
    };
  }
}
