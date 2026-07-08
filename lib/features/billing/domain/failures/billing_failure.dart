/// Failures expuestos por la capa de datos de billing.
///
/// Son `Exception` (no `Error`): el bloc las atrapa y traduce a estados de
/// UI. La jerarquía es sellada para forzar al switch del bloc a cubrir todos
/// los casos: un failure nuevo rompe el build, no se cuela silencioso.
///
/// `GET /workspace/billing` viaja bajo workerOnly (cualquier miembro lee su
/// entitlement), así que no hay variante Forbidden. Sus rechazos propios:
/// 409 (claims sin org activa) y 404 (org sin suscripción).
///
/// 401 NO aparece aquí: lo absorbe el AuthInterceptor (refresh transparente
/// o purga + Unauthenticated).
sealed class BillingFailure implements Exception {
  const BillingFailure();
}

/// Sin conexión, DNS, TLS, connection error. Reintentable.
final class BillingNetworkFailure extends BillingFailure {
  const BillingNetworkFailure();
}

/// Timeout específico (connect/send/receive). Distinto de network para que
/// la UI pueda sugerir reintento con copy distinto.
final class BillingTimeoutFailure extends BillingFailure {
  const BillingTimeoutFailure();
}

/// 409: las claims no traen org activa ("switch-org y reintenta"). En la
/// práctica el login ya resuelve la org — es defensa en profundidad del
/// backend, y aquí una variante propia para no confundirla con un 5xx.
final class BillingOrgUnresolvedFailure extends BillingFailure {
  const BillingOrgUnresolvedFailure();
}

/// 404: la org activa no tiene suscripción registrada. El borde de lectura
/// del backend lo traduce tal cual manda el dominio.
final class BillingNotFoundFailure extends BillingFailure {
  const BillingNotFoundFailure();
}

/// 5xx del backend. Distinto de red: el servidor respondió, pero rompió.
final class BillingServerFailure extends BillingFailure {
  const BillingServerFailure();
}

/// Cualquier otro caso (status no contemplado, body malformado, type error
/// al castear). El cliente lo expone como error genérico sin filtrar el
/// status crudo.
final class UnknownBillingFailure extends BillingFailure {
  const UnknownBillingFailure();
}
