import 'package:flutter/material.dart';

import 'product_form_launcher.dart';
import 'product_form_sheet.dart';

/// FAB del catálogo: abre el alta de producto. Vive junto a la página bajo
/// el mismo BlocProvider (la ruta lo monta en el Scaffold).
class ProductCatalogFab extends StatelessWidget {
  const ProductCatalogFab({super.key, this.pickImage, this.thumbLoader});

  /// Seams de test del formulario; null ⇒ galería y resolver reales.
  final ProductImagePicker? pickImage;
  final ProductThumbLoader? thumbLoader;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      key: const Key('product_catalog.fab'),
      tooltip: 'Nuevo producto',
      onPressed: () => openProductCreate(
        context,
        pickImage: pickImage,
        thumbLoader: thumbLoader,
      ),
      child: const Icon(Icons.add),
    );
  }
}
