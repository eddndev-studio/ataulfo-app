import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_search_field.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_catalog_cubit.dart';

/// Filtros del catálogo: búsqueda difusa y chips de kind/categoría. Ambos
/// son disparadores delgados hacia el [ProductCatalogCubit]; la verdad de
/// los filtros activos vive en el cubit (espejada en su estado).

/// Campo de búsqueda del catálogo. Debounced: dispara `setQuery` 350 ms tras
/// la última tecla, para no consultar `/search` en cada pulsación. El botón
/// de limpiar resetea la búsqueda al instante.
class ProductCatalogSearchField extends StatefulWidget {
  const ProductCatalogSearchField({super.key});

  @override
  State<ProductCatalogSearchField> createState() =>
      _ProductCatalogSearchFieldState();
}

class _ProductCatalogSearchFieldState extends State<ProductCatalogSearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.isEmpty) {
      unawaited(context.read<ProductCatalogCubit>().setQuery(''));
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      unawaited(context.read<ProductCatalogCubit>().setQuery(value));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.sp4,
        AppTokens.sp3,
        AppTokens.sp4,
        0,
      ),
      child: AppSearchField(
        key: const Key('product_catalog.search_field'),
        hint: 'Buscar por nombre o descripción…',
        controller: _controller,
        onChanged: _onChanged,
        clearButtonKey: const Key('product_catalog.search_clear'),
      ),
    );
  }
}

/// Chips de refinado: kind (Productos/Servicios) y las categorías existentes
/// de la org. Tocar un chip seleccionado lo destoggle (quita ese filtro).
/// Refinan client-side sobre el resultado vigente; no vuelven a la red.
class ProductCatalogFilterChips extends StatelessWidget {
  const ProductCatalogFilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ProductCatalogCubit>();
    final state = cubit.state;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp4,
          vertical: AppTokens.sp2,
        ),
        children: <Widget>[
          for (final (ProductKind kind, String label)
              in const <(ProductKind, String)>[
                (ProductKind.product, 'Productos'),
                (ProductKind.service, 'Servicios'),
              ])
            Padding(
              padding: const EdgeInsets.only(right: AppTokens.sp2),
              child: AppChoiceChip(
                key: Key('product_catalog.kind_chip.${kind.name}'),
                label: label,
                selected: state.kind == kind,
                onSelected: (_) =>
                    cubit.setKind(state.kind == kind ? null : kind),
              ),
            ),
          for (final cat in state.categories)
            Padding(
              padding: const EdgeInsets.only(right: AppTokens.sp2),
              child: AppChoiceChip(
                key: Key('product_catalog.category_chip.$cat'),
                label: cat,
                selected: state.category == cat,
                onSelected: (_) =>
                    cubit.setCategory(state.category == cat ? null : cat),
              ),
            ),
        ],
      ),
    );
  }
}
