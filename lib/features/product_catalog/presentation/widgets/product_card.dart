import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_media_thumb.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/product.dart';

/// Tarjeta de un producto del catálogo: miniatura (o glifo), nombre,
/// categoría, precio legible y chip de naturaleza. Inactivo ⇒ contenido
/// atenuado (el chip de kind se mantiene pleno como identidad de la fila).
/// Tap ⇒ el caller abre la edición.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.thumbLoader,
  });

  final Product product;
  final VoidCallback onTap;

  /// Cómo se obtienen los bytes de la miniatura del `mediaRef` BARE
  /// (típicamente `ProductThumbResolver.session`); los tests inyectan fakes.
  final AppMediaThumbLoader thumbLoader;

  static const double _thumbSide = 56;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = product;
    // Rótulo local cuando el backend no publica precio (priceCents = 0).
    final price = p.priceDisplay.isEmpty
        ? 'Precio a consultar'
        : p.priceDisplay;
    final caption = <String>[
      if (p.category.isNotEmpty) p.category,
      if (!p.active) 'inactivo',
    ].join(' · ');
    return AppCard(
      child: InkWell(
        key: Key('product_catalog.card.${p.id}'),
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Opacity(
              key: const Key('product_catalog.card.dim'),
              opacity: p.active ? 1.0 : 0.5,
              child: Row(
                children: <Widget>[
                  if (p.hasImage)
                    AppMediaThumb(
                      key: ValueKey('product_catalog.thumb.${p.mediaRef}'),
                      mediaRef: p.mediaRef,
                      loader: thumbLoader,
                      kind: AppMediaKind.image,
                      size: _thumbSide,
                    )
                  else
                    const _ProductGlyph(side: _thumbSide),
                  const SizedBox(width: AppTokens.sp3),
                ],
              ),
            ),
            Expanded(
              child: Opacity(
                opacity: p.active ? 1.0 : 0.5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge,
                    ),
                    if (caption.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTokens.text2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppTokens.sp3),
            AppPill.outline(
              label: switch (p.kind) {
                ProductKind.product => 'PRODUCTO',
                ProductKind.service => 'SERVICIO',
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Glifo de respaldo cuando el producto no tiene imagen: mismo encuadre que
/// la miniatura para que la lista no salte entre filas con y sin foto.
class _ProductGlyph extends StatelessWidget {
  const _ProductGlyph({required this.side});

  final double side;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: side,
      height: side,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        child: const ColoredBox(
          color: AppTokens.surface2,
          child: Center(
            child: Icon(
              Icons.storefront_outlined,
              color: AppTokens.text2,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
