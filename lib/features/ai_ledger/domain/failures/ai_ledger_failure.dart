/// Failures de la bitácora de acciones. Jerarquía sellada mínima, espejo de la
/// del ai-log: la página solo distingue red (reintentable), permisos y resto.
sealed class AiLedgerFailure implements Exception {
  const AiLedgerFailure();
}

/// Timeout, sin conexión, DNS, TLS. Reintentable.
final class AiLedgerNetworkFailure extends AiLedgerFailure {
  const AiLedgerNetworkFailure();
}

/// 403: el rol no alcanza (la bitácora es ADMIN+).
final class AiLedgerForbiddenFailure extends AiLedgerFailure {
  const AiLedgerForbiddenFailure();
}

/// 5xx o cualquier otro caso no contemplado.
final class AiLedgerUnknownFailure extends AiLedgerFailure {
  const AiLedgerUnknownFailure();
}
