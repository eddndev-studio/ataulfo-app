import '../../domain/entities/product.dart';
import '../dto/product_dto.dart';

/// Convierte el DTO del wire a la entidad de dominio: parsea el `kind` del
/// set cerrado (`PRODUCT`/`SERVICE`) y los instantes RFC3339 a `DateTime`
/// UTC. Un kind fuera del set o una fecha malformada son wire roto
/// (`FormatException`), no casos a tolerar.
class ProductMapper {
  const ProductMapper._();

  static Product dtoToEntity(ProductDto dto) => Product(
    id: dto.id,
    kind: kindFromWire(dto.kind),
    name: dto.name,
    description: dto.description,
    category: dto.category,
    priceCents: dto.priceCents,
    priceDisplay: dto.priceDisplay,
    mediaRef: dto.mediaRef,
    active: dto.active,
    createdAt: DateTime.parse(dto.createdAt).toUtc(),
    updatedAt: DateTime.parse(dto.updatedAt).toUtc(),
  );

  static ProductKind kindFromWire(String wire) => switch (wire) {
    'PRODUCT' => ProductKind.product,
    'SERVICE' => ProductKind.service,
    _ => throw FormatException('kind de producto desconocido: $wire'),
  };

  static String kindToWire(ProductKind kind) => switch (kind) {
    ProductKind.product => 'PRODUCT',
    ProductKind.service => 'SERVICE',
  };
}
