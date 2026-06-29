/// Fallos del flujo de config de IA de la org. Sellada: el bloc/UI ramifica con
/// `switch` exhaustivo. Espeja la taxonomía de templates (forbidden / invalid /
/// network / server / unknown) porque comparte la pila HTTP y el gate admin.
sealed class OrgAiConfigFailure implements Exception {
  const OrgAiConfigFailure();
}

/// 403: el rol activo no es ADMIN/OWNER. El backend es la autoridad real (el
/// gate de UI es cosmético); un WORKER que llegue por deep-link cae aquí.
class OrgAiConfigForbiddenFailure extends OrgAiConfigFailure {
  const OrgAiConfigForbiddenFailure();
}

/// 422: la config rechazada por el dominio del backend (un host no ofrecido por
/// el catálogo para ese modelo, o defaults inválidos).
class OrgAiConfigInvalidFailure extends OrgAiConfigFailure {
  const OrgAiConfigInvalidFailure();
}

/// Sin red / timeout: reintentable sin cambiar nada.
class OrgAiConfigNetworkFailure extends OrgAiConfigFailure {
  const OrgAiConfigNetworkFailure();
}

/// 5xx u otro fallo del servidor.
class OrgAiConfigServerFailure extends OrgAiConfigFailure {
  const OrgAiConfigServerFailure();
}

/// Respuesta ilegible / caso no clasificado.
class UnknownOrgAiConfigFailure extends OrgAiConfigFailure {
  const UnknownOrgAiConfigFailure();
}
