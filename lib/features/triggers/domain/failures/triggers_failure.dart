/// Failures expuestos por la capa de datos de Triggers (S11).
///
/// Son `Exception` (no `Error`): el llamador es el bloc, que las atrapa y
/// las traduce a estados de UI. Jerarquía sellada para forzar al switch
/// del bloc a cubrir todos los casos.
///
/// 401 NO aparece aquí: lo absorbe el AuthInterceptor (refresh transparente
/// o purga + Unauthenticated). Si llega aquí, el access renovado también
/// falló — colapsa a la lógica global de logout.
///
/// 4xx específicos de mutaciones (409 CAS, 422 invalid) no viven en el
/// slice read-only: los habilitan los slices de crear/editar/borrar
/// trigger.
sealed class TriggersFailure implements Exception {
  const TriggersFailure();
}

/// Timeout, sin conexión, DNS, TLS. Reintentable por acción del usuario.
final class TriggersNetworkFailure extends TriggersFailure {
  const TriggersNetworkFailure();
}

/// Timeout específico (connect/receive). Distinto del genérico de red
/// para que la UI pueda sugerir reintento con copy más útil.
final class TriggersTimeoutFailure extends TriggersFailure {
  const TriggersTimeoutFailure();
}

/// 403 contra `/templates/:id/triggers`: el rol del operador no alcanza
/// (ADMIN+ según S11). No se reintenta solo.
final class TriggersForbiddenFailure extends TriggersFailure {
  const TriggersForbiddenFailure();
}

/// 404 contra `/templates/:id/triggers`: la Template padre no existe en
/// la org del operador (o fue borrada). Reintentar el mismo id volverá
/// a fallar — la UI debe mostrar estado terminal sin retry.
final class TriggersNotFoundFailure extends TriggersFailure {
  const TriggersNotFoundFailure();
}

/// 5xx del backend. El servidor respondió pero rompió — distinto de red.
final class TriggersServerFailure extends TriggersFailure {
  const TriggersServerFailure();
}

/// Cualquier otro caso (status no contemplado, body malformado, cast roto).
/// El cliente lo expone como error genérico sin filtrar el status crudo.
final class UnknownTriggersFailure extends TriggersFailure {
  const UnknownTriggersFailure();
}
