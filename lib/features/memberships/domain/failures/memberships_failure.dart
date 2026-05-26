/// Failures expuestos por la capa de datos de Memberships.
///
/// Son `Exception` (no `Error`): el bloc las atrapa y traduce a estados de
/// UI. La jerarquía es sellada para forzar al switch del bloc a cubrir
/// todos los casos: un failure nuevo rompe el build, no se cuela silencioso.
///
/// SIN NotFound: GET /auth/memberships nunca devuelve 404 — un caller sin
/// memberships activas recibe `200 con []`. Distinguir "lista vacía" de
/// "endpoint inexistente" es contrato del wire, no de la jerarquía.
///
/// 401 NO aparece aquí: lo absorbe el AuthInterceptor (refresh transparente
/// o purga + Unauthenticated). Si llega a este bloc, significa que el access
/// renovado también falló — colapsa a la lógica global de logout vía
/// onUnrecoverable, no a un estado local del listado.
sealed class MembershipsFailure implements Exception {
  const MembershipsFailure();
}

/// Sin conexión, DNS, TLS, connection error. Reintentable por acción del
/// usuario.
final class MembershipsNetworkFailure extends MembershipsFailure {
  const MembershipsNetworkFailure();
}

/// Timeout específico (connect/send/receive). Distinto de network para que
/// la UI pueda sugerir reintento con tono distinto al genérico de red.
final class MembershipsTimeoutFailure extends MembershipsFailure {
  const MembershipsTimeoutFailure();
}

/// 403 contra `/auth/memberships`: el RBAC del backend rechaza el verbo.
/// Caso poco probable (cualquier usuario autenticado puede leer sus orgs),
/// expuesto explícito para no esconderlo en Unknown.
final class MembershipsForbiddenFailure extends MembershipsFailure {
  const MembershipsForbiddenFailure();
}

/// 5xx del backend. Distinto de red: el servidor respondió, pero rompió.
final class MembershipsServerFailure extends MembershipsFailure {
  const MembershipsServerFailure();
}

/// Cualquier otro caso (status no contemplado, body malformado). El cliente
/// lo expone como error genérico sin filtrar el status crudo.
final class UnknownMembershipsFailure extends MembershipsFailure {
  const UnknownMembershipsFailure();
}
