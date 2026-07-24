import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_page_container.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_catalog_cubit.dart';
import '../product_thumb_resolver.dart';
import '../widgets/product_card.dart';
import '../widgets/product_catalog_filter_bar.dart';
import '../widgets/product_form_launcher.dart';
import '../widgets/product_form_sheet.dart';

/// Ajustes → Catálogo de productos: buscador difuso, chips de refinado y la
/// lista de tarjetas; tocar una tarjeta abre su edición (el detalle v1 ES la
/// edición). Página de una pushed route (la ruta aporta Scaffold + AppBar +
/// FAB de alta). Consume el `ProductCatalogCubit` del scope de la ruta.
///
/// El buscador y los chips viven FUERA del switch de estado: siguen montados
/// (y con foco) mientras una búsqueda pone el listado en loading.
class ProductCatalogPage extends StatelessWidget {
  const ProductCatalogPage({
    super.key,
    this.pickImage,
    this.thumbLoader,
    this.composePhoto,
  });

  /// Seams de test del formulario y las miniaturas; null ⇒ galería picker y
  /// `ProductThumbResolver.session` reales.
  final ProductImagePicker? pickImage;
  final ProductThumbLoader? thumbLoader;

  /// Flujo «Mejorar foto con IA» de la edición. A diferencia de los seams de
  /// arriba, aquí null significa que la acción NO se ofrece: el wiring real
  /// (repos de composición y media) lo inyecta el router.
  final ProductComposePhoto? composePhoto;

  ProductThumbLoader get _thumbLoader =>
      thumbLoader ?? ProductThumbResolver.session.load;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductCatalogCubit, ProductCatalogState>(
      builder: (context, state) {
        return Column(
          children: <Widget>[
            const ProductCatalogSearchField(),
            const ProductCatalogFilterChips(),
            Expanded(
              child: switch (state.status) {
                ProductCatalogStatus.loading => const Center(
                  child: AppLoadingIndicator(),
                ),
                ProductCatalogStatus.error => AppErrorState(
                  message: 'No se pudo cargar el catálogo.',
                  onRetry: () => context.read<ProductCatalogCubit>().load(),
                ),
                ProductCatalogStatus.loaded => _Loaded(
                  state: state,
                  thumbLoader: _thumbLoader,
                  onEdit: (p) => openProductEdit(
                    context,
                    p,
                    pickImage: pickImage,
                    thumbLoader: thumbLoader,
                    composePhoto: composePhoto,
                  ),
                ),
              },
            ),
          ],
        );
      },
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.state,
    required this.thumbLoader,
    required this.onEdit,
  });

  final ProductCatalogState state;
  final ProductThumbLoader thumbLoader;
  final ValueChanged<Product> onEdit;

  bool get _unfiltered =>
      state.query.isEmpty && state.category == null && state.kind == null;

  @override
  Widget build(BuildContext context) {
    final visible = state.visible;
    if (visible.isEmpty) {
      // Catálogo virgen vs. filtros sin match: copys distintos — el primero
      // invita a crear, el segundo a aflojar la búsqueda.
      if (state.items.isEmpty && _unfiltered) {
        return const AppEmptyState(
          key: Key('product_catalog.empty'),
          icon: Icons.storefront_outlined,
          title: 'Aún no hay productos ni servicios',
          description:
              'Crea el primero con el botón + para que tu asistente '
              'pueda ofrecerlo y compartirlo.',
        );
      }
      return const AppEmptyState(
        key: Key('product_catalog.no_results'),
        icon: Icons.search_off_outlined,
        title: 'Sin resultados',
        description: 'Ajusta la búsqueda o quita filtros.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppPageGutters.primary,
        AppTokens.sp3,
        AppPageGutters.primary,
        AppTokens.sp5 + context.safeBottomInset,
      ),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTokens.sp3),
      itemBuilder: (context, i) {
        final p = visible[i];
        return ProductCard(
          product: p,
          onTap: () => onEdit(p),
          thumbLoader: (ref) => thumbLoader(ref),
        );
      },
    );
  }
}
