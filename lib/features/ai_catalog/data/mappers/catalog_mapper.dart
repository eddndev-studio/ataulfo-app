import '../../domain/entities/catalog.dart';
import '../dto/catalog_dto.dart';

/// Traduce el DTO del wire (GET /ai/catalog) a la entidad de dominio.
///
/// Pura para que cualquier llamador (datasource, test) la componga sin
/// estado. Vive en `data/` porque conoce el shape del wire; el dominio no.
class CatalogMapper {
  const CatalogMapper._();

  static Catalog respToEntity(CatalogResp resp) => Catalog(
    providers: resp.providers
        .map(_providerEntryDtoToEntity)
        .toList(growable: false),
  );

  static ProviderEntry _providerEntryDtoToEntity(ProviderEntryDto dto) =>
      ProviderEntry(
        provider: dto.provider,
        defaultModel: dto.defaultModel,
        models: dto.models.map(_modelDtoToEntity).toList(growable: false),
      );

  static AIModel _modelDtoToEntity(ModelDto dto) => AIModel(
    id: dto.id,
    supportsTemperature: dto.supportsTemperature,
    supportsThinking: dto.supportsThinking,
  );
}
