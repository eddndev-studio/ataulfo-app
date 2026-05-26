import 'entities/catalog.dart';

/// Helpers de "drift" entre la AIConfig de una Template y el catálogo
/// vivo del backend.
///
/// Razón de existir: el cliente conoce los enums `AIProvider`/
/// `ThinkingLevel` cerrados (fail-loud para altas), pero el catálogo
/// puede *bajar* proveedores o modelos entre releases sin romper el
/// fromWire de un Template guardado. El editor de AIConfig necesita
/// detectar el drift para forzar al operador a re-elegir antes de
/// permitir el submit.
///
/// Pura: ni entidad, ni IO, ni estado. Inputs immutables → output
/// determinista; testeable sin Dio ni Bloc.

/// Devuelve la entrada del catálogo para `providerWire` o `null` si el
/// proveedor no está disponible en el catálogo vivo.
ProviderEntry? catalogProvider(Catalog catalog, String providerWire) {
  for (final entry in catalog.providers) {
    if (entry.provider == providerWire) return entry;
  }
  return null;
}

/// Devuelve el modelo del catálogo para `(providerWire, modelId)` o
/// `null` si el proveedor no está, o si está pero el modelo fue
/// retirado entre releases.
AIModel? catalogModel(Catalog catalog, String providerWire, String modelId) {
  final entry = catalogProvider(catalog, providerWire);
  if (entry == null) return null;
  for (final model in entry.models) {
    if (model.id == modelId) return model;
  }
  return null;
}
