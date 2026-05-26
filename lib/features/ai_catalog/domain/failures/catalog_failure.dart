/// Failures expuestos por la capa de datos del catálogo IA.
///
/// Son `Exception` (no `Error`): el bloc las atrapa y traduce a estados
/// de UI. La jerarquía es sellada para forzar al switch del bloc a cubrir
/// todos los casos: un failure nuevo rompe el build, no se cuela silencioso.
///
/// SIN NotFound: `GET /ai/catalog` siempre existe (la tabla viaja con el
/// binario del backend). SIN InvalidName/Update: read-only sin body.
///
/// 401 NO aparece aquí: lo absorbe el AuthInterceptor (refresh transparente
/// o purga + Unauthenticated). Si llega a este bloc significa que el access
/// renovado también falló — colapsa a la lógica global de logout.
sealed class CatalogFailure implements Exception {
  const CatalogFailure();
}

/// Sin conexión, DNS, TLS, connection error. Reintentable.
final class CatalogNetworkFailure extends CatalogFailure {
  const CatalogNetworkFailure();
}

/// Timeout específico (connect/send/receive). Distinto de network para que
/// la UI pueda sugerir reintento con copy distinto.
final class CatalogTimeoutFailure extends CatalogFailure {
  const CatalogTimeoutFailure();
}

/// 403 contra `/ai/catalog`: el endpoint está envuelto en adminOnly (misma
/// pila que `/templates`); WORKER/SUPERVISOR caen acá. La UI debe mostrar
/// un estado terminal — reintentar con el mismo rol vuelve a fallar.
final class CatalogForbiddenFailure extends CatalogFailure {
  const CatalogForbiddenFailure();
}

/// 5xx del backend. Distinto de red: el servidor respondió, pero rompió.
final class CatalogServerFailure extends CatalogFailure {
  const CatalogServerFailure();
}

/// Cualquier otro caso (status no contemplado, body malformado, type error
/// al castear la lista). El cliente lo expone como error genérico sin
/// filtrar el status crudo.
final class UnknownCatalogFailure extends CatalogFailure {
  const UnknownCatalogFailure();
}
