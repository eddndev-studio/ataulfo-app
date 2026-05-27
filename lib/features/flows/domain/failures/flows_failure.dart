/// Failures expuestos por la capa de datos de Flows (S11).
///
/// Son `Exception` (no `Error`): el llamador es el bloc, que las atrapa y
/// las traduce a estados de UI. Jerarquía sellada para forzar al switch
/// del bloc a cubrir todos los casos.
///
/// 401 NO aparece aquí: lo absorbe el AuthInterceptor (refresh transparente
/// o purga + Unauthenticated). Si llega aquí, el access renovado también
/// falló — colapsa a la lógica global de logout vía onUnrecoverable.
///
/// 4xx específicos de mutaciones (409 CAS, 422 invalid) no viven en F1
/// (read-only): los habilitan los slices de crear/editar/borrar flow.
sealed class FlowsFailure implements Exception {
  const FlowsFailure();
}

/// Timeout, sin conexión, DNS, TLS. Reintentable por acción del usuario.
final class FlowsNetworkFailure extends FlowsFailure {
  const FlowsNetworkFailure();
}

/// Timeout específico (connect/receive). Distinto del genérico de red
/// para que la UI pueda sugerir reintento con copy más útil.
final class FlowsTimeoutFailure extends FlowsFailure {
  const FlowsTimeoutFailure();
}

/// 403 contra `/templates/:id/flows`: el rol del operador no alcanza para
/// el verbo (ADMIN+ según S11). No se reintenta solo.
final class FlowsForbiddenFailure extends FlowsFailure {
  const FlowsForbiddenFailure();
}

/// 404 contra `/templates/:id/flows`: la Template padre no existe en la
/// org del operador (o fue borrada). Reintentar el mismo id volverá a
/// fallar — la UI debe mostrar estado terminal sin retry.
final class FlowsNotFoundFailure extends FlowsFailure {
  const FlowsNotFoundFailure();
}

/// 5xx del backend. El servidor respondió pero rompió — distinto de red.
final class FlowsServerFailure extends FlowsFailure {
  const FlowsServerFailure();
}

/// Cualquier otro caso (status no contemplado, body malformado, cast roto).
/// El cliente lo expone como error genérico sin filtrar el status crudo.
final class UnknownFlowsFailure extends FlowsFailure {
  const UnknownFlowsFailure();
}
