/// Fallas tipadas del módulo de personalización de la organización. Mismo
/// catálogo que el resto de features org-level: la capa de datos traduce
/// DioException a estos tipos y la UI decide la copy.
sealed class OrgBrandingFailure implements Exception {
  const OrgBrandingFailure();
}

/// Sin conexión o timeout.
class OrgBrandingNetworkFailure extends OrgBrandingFailure {
  const OrgBrandingNetworkFailure();
}

/// 403: el rol no alcanza (ADMIN+). El gate de la UI es cosmético; la
/// autoridad real es este error del servidor.
class OrgBrandingForbiddenFailure extends OrgBrandingFailure {
  const OrgBrandingForbiddenFailure();
}

/// 422: el logo no es utilizable (ref ajeno o inválido, tipo no incluible,
/// sobre tope).
class OrgBrandingInvalidFailure extends OrgBrandingFailure {
  const OrgBrandingInvalidFailure();
}

/// 5xx del backend.
class OrgBrandingServerFailure extends OrgBrandingFailure {
  const OrgBrandingServerFailure();
}

/// Cualquier otro fallo (contrato roto, cancelación, desconocido).
class UnknownOrgBrandingFailure extends OrgBrandingFailure {
  const UnknownOrgBrandingFailure();
}
