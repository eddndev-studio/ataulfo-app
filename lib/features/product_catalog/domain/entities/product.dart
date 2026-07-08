/// Naturaleza de una entrada del catálogo: bien tangible o servicio. Set
/// cerrado del dominio del backend; el wire viaja en mayúsculas
/// (`PRODUCT`/`SERVICE`) y el mapper hace la conversión.
enum ProductKind { product, service }

/// Entrada del catálogo de la organización: lo que el asistente puede ofrecer
/// y compartir con los clientes (un producto físico o un servicio).
///
/// El precio vive en centavos ([priceCents]); [priceDisplay] es el precio
/// legible que fabrica el backend (fuente única del formato MXN). Vacío ⇒
/// sin precio publicado: la UI rotula «a consultar», nunca "$0.00".
///
/// [mediaRef] es el identificador BARE de la imagen en la galería de medios
/// ('' = sin imagen). Como en el resto de la app, el ref es la única
/// identidad del recurso; jamás una URL firmada.
class Product {
  const Product({
    required this.id,
    required this.kind,
    required this.name,
    required this.description,
    required this.category,
    required this.priceCents,
    required this.priceDisplay,
    required this.mediaRef,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final ProductKind kind;
  final String name;
  final String description;

  /// Categoría libre de la org ('' = sin categoría). El backend deriva el
  /// catálogo de categorías existentes de estos valores.
  final String category;

  /// Precio en centavos de peso. 0 ⇒ «a consultar».
  final int priceCents;

  /// Precio legible fabricado por el backend (p. ej. `$1,250.00 MXN`).
  /// '' cuando [priceCents] es 0.
  final String priceDisplay;

  /// Ref BARE de la imagen en la galería ('' = sin imagen).
  final String mediaRef;

  /// Inactivo ⇒ el asistente no lo ofrece; la UI lo pinta atenuado. El
  /// backend nunca borra productos.
  final bool active;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasPrice => priceCents > 0;

  bool get hasImage => mediaRef.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product &&
        other.id == id &&
        other.kind == kind &&
        other.name == name &&
        other.description == description &&
        other.category == category &&
        other.priceCents == priceCents &&
        other.priceDisplay == priceDisplay &&
        other.mediaRef == mediaRef &&
        other.active == active &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    name,
    description,
    category,
    priceCents,
    priceDisplay,
    mediaRef,
    active,
    createdAt,
    updatedAt,
  );
}
