import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/product.dart';
import '../bloc/product_catalog_cubit.dart';
import 'product_form_sheet.dart';

/// Abre el alta de producto cableada al [ProductCatalogCubit] del scope: las
/// categorías del estado como sugerencias y el submit contra `create`. El
/// producto nace activo (el toggle vive solo en la edición).
Future<void> openProductCreate(
  BuildContext context, {
  ProductImagePicker? pickImage,
  ProductThumbLoader? thumbLoader,
}) {
  final cubit = context.read<ProductCatalogCubit>();
  return ProductFormSheet.open(
    context,
    categories: cubit.state.categories,
    pickImage: pickImage,
    thumbLoader: thumbLoader,
    onSubmit:
        ({
          required ProductKind kind,
          required String name,
          required String description,
          required String category,
          required int priceCents,
          required String mediaRef,
          required bool active,
        }) => cubit.create(
          kind: kind,
          name: name,
          description: description,
          category: category,
          priceCents: priceCents,
          mediaRef: mediaRef,
          active: active,
        ),
  );
}

/// Abre la edición de [product] cableada al cubit del scope (submit contra
/// `update` con el id del producto). El detalle v1 ES esta edición.
Future<void> openProductEdit(
  BuildContext context,
  Product product, {
  ProductImagePicker? pickImage,
  ProductThumbLoader? thumbLoader,
}) {
  final cubit = context.read<ProductCatalogCubit>();
  return ProductFormSheet.open(
    context,
    initial: product,
    categories: cubit.state.categories,
    pickImage: pickImage,
    thumbLoader: thumbLoader,
    onSubmit:
        ({
          required ProductKind kind,
          required String name,
          required String description,
          required String category,
          required int priceCents,
          required String mediaRef,
          required bool active,
        }) => cubit.update(
          id: product.id,
          kind: kind,
          name: name,
          description: description,
          category: category,
          priceCents: priceCents,
          mediaRef: mediaRef,
          active: active,
        ),
  );
}
