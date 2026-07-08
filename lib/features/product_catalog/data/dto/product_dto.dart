/// DTO del wire de un producto del catálogo
/// (`GET /workspace/catalog/products`).
///
/// Las claves viajan en camelCase (consistente con el adaptador Go del
/// catálogo). Todos los campos son obligatorios y el backend los emite
/// siempre (sin omitempty): un faltante o un tipo inválido es un wire roto,
/// no un caso a tolerar. `kind`, `createdAt` y `updatedAt` se quedan como
/// strings del wire; el mapper los convierte al dominio.
class ProductDto {
  const ProductDto({
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

  factory ProductDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final kind = json['kind'];
    final name = json['name'];
    final description = json['description'];
    final category = json['category'];
    final priceCents = json['priceCents'];
    final priceDisplay = json['priceDisplay'];
    final mediaRef = json['mediaRef'];
    final active = json['active'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    if (id is! String ||
        kind is! String ||
        name is! String ||
        description is! String ||
        category is! String ||
        priceCents is! int ||
        priceDisplay is! String ||
        mediaRef is! String ||
        active is! bool ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException(
        'producto: clave obligatoria ausente o tipo inválido',
      );
    }
    return ProductDto(
      id: id,
      kind: kind,
      name: name,
      description: description,
      category: category,
      priceCents: priceCents,
      priceDisplay: priceDisplay,
      mediaRef: mediaRef,
      active: active,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  final String id;
  final String kind;
  final String name;
  final String description;
  final String category;
  final int priceCents;
  final String priceDisplay;
  final String mediaRef;
  final bool active;
  final String createdAt;
  final String updatedAt;
}
