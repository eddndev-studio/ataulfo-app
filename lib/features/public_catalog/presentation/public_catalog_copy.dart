import '../domain/failures/public_catalog_failure.dart';

/// Traduce una falla tipada a copy es-MX para la UI. Única frontera que conoce
/// las causas; la vista nunca arma texto a partir de un código de wire.
String publicCatalogFailureCopy(PublicCatalogFailure? f) => switch (f) {
  PublicCatalogNetworkFailure() =>
    'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
  PublicCatalogForbiddenFailure() =>
    'Solo un administrador puede cambiar el catálogo público.',
  PublicCatalogInvalidSlugFailure() =>
    'El enlace solo admite minúsculas, números y guiones (3 a 40 caracteres).',
  PublicCatalogSlugTakenFailure() =>
    'Ese enlace ya lo usa otro negocio. Prueba con uno distinto.',
  PublicCatalogServerFailure() =>
    'El servidor tuvo un problema. Inténtalo más tarde.',
  PublicCatalogUnknownFailure() ||
  null => 'No se pudo completar la acción. Inténtalo de nuevo.',
};
