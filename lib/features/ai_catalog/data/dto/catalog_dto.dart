/// DTOs del wire de `GET /ai/catalog`.
///
/// Las claves del wire ya son camelCase (el adaptador Go encoda
/// `providers`, `defaultModel`, `supportsTemperature`, `supportsThinking`
/// directo) — los DTOs no traducen nombres, solo validan tipos y
/// presencia. El mapper convierte DTO ⇄ entidad de dominio.
class CatalogResp {
  const CatalogResp({required this.providers});

  factory CatalogResp.fromJson(Map<String, dynamic> json) {
    final providers = json['providers'];
    if (providers is! List) {
      throw const FormatException(
        'catalogResp: clave obligatoria "providers" ausente o tipo inválido',
      );
    }
    return CatalogResp(
      providers: providers
          .cast<Map<String, dynamic>>()
          .map(ProviderEntryDto.fromJson)
          .toList(growable: false),
    );
  }

  final List<ProviderEntryDto> providers;
}

class ProviderEntryDto {
  const ProviderEntryDto({
    required this.provider,
    required this.defaultModel,
    required this.models,
  });

  factory ProviderEntryDto.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'];
    final defaultModel = json['defaultModel'];
    final models = json['models'];
    if (provider is! String || defaultModel is! String) {
      throw const FormatException(
        'providerEntry: clave obligatoria ausente o tipo inválido',
      );
    }
    if (models is! List) {
      throw const FormatException('providerEntry: "models" debe ser lista');
    }
    return ProviderEntryDto(
      provider: provider,
      defaultModel: defaultModel,
      models: models
          .cast<Map<String, dynamic>>()
          .map(ModelDto.fromJson)
          .toList(growable: false),
    );
  }

  final String provider;
  final String defaultModel;
  final List<ModelDto> models;
}

class ModelDto {
  const ModelDto({
    required this.id,
    required this.supportsTemperature,
    required this.supportsThinking,
    this.supportsImageInput = false,
    this.supportsAudioInput = false,
    this.supportsDocumentInput = false,
  });

  factory ModelDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final supportsTemperature = json['supportsTemperature'];
    final supportsThinking = json['supportsThinking'];
    if (id is! String ||
        supportsTemperature is! bool ||
        supportsThinking is! bool) {
      throw const FormatException(
        'model: clave obligatoria ausente o tipo inválido',
      );
    }
    // Modalidades de entrada: TOLERANTES (ausentes ⇒ false) — el wire las
    // ganó después y un backend viejo no debe romper el catálogo.
    return ModelDto(
      id: id,
      supportsTemperature: supportsTemperature,
      supportsThinking: supportsThinking,
      supportsImageInput: json['supportsImageInput'] == true,
      supportsAudioInput: json['supportsAudioInput'] == true,
      supportsDocumentInput: json['supportsDocumentInput'] == true,
    );
  }

  final String id;
  final bool supportsTemperature;
  final bool supportsThinking;
  final bool supportsImageInput;
  final bool supportsAudioInput;
  final bool supportsDocumentInput;
}
