/// Failures de la vista de observabilidad del bot. Jerarquía sellada
/// mínima: la página solo distingue red (reintentable), permisos y resto.
sealed class AiLogFailure implements Exception {
  const AiLogFailure();
}

/// Timeout, sin conexión, DNS, TLS. Reintentable.
final class AiLogNetworkFailure extends AiLogFailure {
  const AiLogNetworkFailure();
}

/// 403: el rol no alcanza (la vista es ADMIN+).
final class AiLogForbiddenFailure extends AiLogFailure {
  const AiLogForbiddenFailure();
}

/// 5xx o cualquier otro caso no contemplado.
final class AiLogUnknownFailure extends AiLogFailure {
  const AiLogUnknownFailure();
}
