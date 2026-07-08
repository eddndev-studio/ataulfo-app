import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_media_thumb.dart';
import '../../../media/domain/entities/media_asset.dart';
import 'product_form_sheet.dart';

/// Sección de imagen del formulario: sin ref muestra el botón de elegir de la
/// galería; con ref, la miniatura efímera + cambiar/quitar. El ref BARE es lo
/// único que se envía; la miniatura es un adorno best-effort.
class ProductFormImageSection extends StatelessWidget {
  const ProductFormImageSection({
    super.key,
    required this.mediaRef,
    required this.pickedAsset,
    required this.thumbLoader,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final String mediaRef;

  /// Asset efímero de la selección de esta sesión del formulario; solo
  /// habilita la miniatura fresca — jamás se persiste.
  final MediaAsset? pickedAsset;
  final ProductThumbLoader thumbLoader;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (mediaRef.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: AppButton.tonal(
          key: const Key('product_form.pick_image'),
          label: 'Elegir imagen de la galería',
          icon: Icons.image_outlined,
          onPressed: enabled ? onPick : null,
        ),
      );
    }
    // El asset elegido sólo describe al ref vigente; en edición sin
    // re-selección no hay asset y la miniatura sale del cache (o el glifo).
    final picked = pickedAsset?.ref == mediaRef ? pickedAsset : null;
    return Container(
      key: const Key('product_form.image_selected'),
      padding: const EdgeInsets.all(AppTokens.sp3),
      decoration: BoxDecoration(
        color: AppTokens.surface2,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: Row(
        children: <Widget>[
          AppMediaThumb(
            // El key incluye si hay asset: cuando APARECE para el mismo ref
            // el remount re-resuelve con la fuente nueva.
            key: ValueKey('product_form.thumb.$mediaRef#${picked != null}'),
            mediaRef: mediaRef,
            kind: AppMediaKind.image,
            size: 56,
            loader: (r) => thumbLoader(r, asset: picked),
          ),
          const SizedBox(width: AppTokens.sp3),
          Expanded(
            child: Text(
              picked?.displayName ?? 'Imagen de la galería',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
            ),
          ),
          AppButton.text(
            key: const Key('product_form.change_image'),
            label: 'Cambiar',
            onPressed: enabled ? onPick : null,
          ),
          AppButton.text(
            key: const Key('product_form.remove_image'),
            label: 'Quitar',
            onPressed: enabled ? onRemove : null,
          ),
        ],
      ),
    );
  }
}
