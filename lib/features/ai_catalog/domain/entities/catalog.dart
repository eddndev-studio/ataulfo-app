/// Catálogo de proveedores y modelos del Motor IA expuesto por
/// `GET /ai/catalog`. Es una tabla estática del backend, no datos por-org:
/// el cliente la lee una vez por sesión (o por demanda del editor de
/// AIConfig) y alimenta los pickers de provider/model.
///
/// `provider` viaja como `String` crudo (no enum cerrado): el backend
/// puede ganar un proveedor entre releases del cliente y el `fromJson` no
/// debe romperse por una entrada legítima del wire. El editor de AIConfig
/// decide qué hacer con un provider que no reconoce (mostrarlo si el
/// `AIProvider.fromWire` lo acepta, esconder si no).
class Catalog {
  const Catalog({required this.providers});

  final List<ProviderEntry> providers;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Catalog) return false;
    if (other.providers.length != providers.length) return false;
    for (var i = 0; i < providers.length; i++) {
      if (other.providers[i] != providers[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(providers);
}

/// Un proveedor del catálogo. `defaultModel` es la sugerencia del backend
/// al elegir este proveedor en el editor; `models` es el listado ordenado
/// por preferencia del backend (no se reordena cliente).
class ProviderEntry {
  const ProviderEntry({
    required this.provider,
    required this.defaultModel,
    required this.models,
  });

  final String provider;
  final String defaultModel;
  final List<AIModel> models;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProviderEntry) return false;
    if (other.provider != provider) return false;
    if (other.defaultModel != defaultModel) return false;
    if (other.models.length != models.length) return false;
    for (var i = 0; i < models.length; i++) {
      if (other.models[i] != models[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(provider, defaultModel, Object.hashAll(models));
}

/// Un modelo concreto del catálogo. Las dos flags de capacidad determinan
/// qué controles muestra el editor de AIConfig:
///
///   - `supportsTemperature`: el modelo honra una temperatura no-default.
///     GPT-5 la rechaza; Gemini 3, MiniMax y DeepSeek la aceptan. Cuando
///     es `false`, el editor oculta el slider.
///   - `supportsThinking`: el modelo expone una perilla de razonamiento
///     mapeable a `thinkingLevel`. MiniMax/DeepSeek razonan nativos sin
///     perilla; el editor oculta el dropdown cuando es `false`.
class AIModel {
  const AIModel({
    required this.id,
    required this.supportsTemperature,
    required this.supportsThinking,
  });

  final String id;
  final bool supportsTemperature;
  final bool supportsThinking;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIModel &&
        other.id == id &&
        other.supportsTemperature == supportsTemperature &&
        other.supportsThinking == supportsThinking;
  }

  @override
  int get hashCode => Object.hash(id, supportsTemperature, supportsThinking);
}
