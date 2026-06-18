/// Failures del historial de ejecuciones. Jerarquía sellada mínima: la página
/// sólo distingue red (reintentable), permisos y resto.
sealed class ExecutionFailure implements Exception {
  const ExecutionFailure();
}

/// Timeout, sin conexión, DNS, TLS. Reintentable.
final class ExecutionNetworkFailure extends ExecutionFailure {
  const ExecutionNetworkFailure();
}

/// 403: el rol no alcanza (la vista es ADMIN+).
final class ExecutionForbiddenFailure extends ExecutionFailure {
  const ExecutionForbiddenFailure();
}

/// 5xx o cualquier otro caso no contemplado.
final class ExecutionUnknownFailure extends ExecutionFailure {
  const ExecutionUnknownFailure();
}
