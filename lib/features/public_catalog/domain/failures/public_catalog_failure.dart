/// Fallas tipadas del catálogo público. El datasource traduce el wire (status
/// + código estable) a estas; la presentación las traduce a copy es-MX. El
/// código crudo del wire JAMÁS llega a la UI.
sealed class PublicCatalogFailure implements Exception {
  const PublicCatalogFailure();
}

/// Red caída / timeout: la petición no llegó o no volvió.
class PublicCatalogNetworkFailure extends PublicCatalogFailure {
  const PublicCatalogNetworkFailure();
}

/// 403: el rol no alcanza (la superficie es ADMIN+).
class PublicCatalogForbiddenFailure extends PublicCatalogFailure {
  const PublicCatalogForbiddenFailure();
}

/// 422 invalid_slug: el enlace propuesto no cumple la forma o es reservado.
class PublicCatalogInvalidSlugFailure extends PublicCatalogFailure {
  const PublicCatalogInvalidSlugFailure();
}

/// 422 invalid_design / invalid_accent: el diseño o color propuesto no existe
/// en el backend (app desactualizada frente a un enum que se recortó, o un
/// valor manipulado). Distinta del slug: el usuario no debe "corregir" el
/// enlace por un rechazo de apariencia.
class PublicCatalogInvalidAppearanceFailure extends PublicCatalogFailure {
  const PublicCatalogInvalidAppearanceFailure();
}

/// 409 slug_taken: otro negocio ya usa ese enlace.
class PublicCatalogSlugTakenFailure extends PublicCatalogFailure {
  const PublicCatalogSlugTakenFailure();
}

/// 5xx: avería del servidor.
class PublicCatalogServerFailure extends PublicCatalogFailure {
  const PublicCatalogServerFailure();
}

/// Cualquier otra cosa (wire roto, status inesperado): degradación honesta.
class PublicCatalogUnknownFailure extends PublicCatalogFailure {
  const PublicCatalogUnknownFailure();
}
