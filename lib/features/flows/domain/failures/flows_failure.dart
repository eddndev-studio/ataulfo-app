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

/// 422 contra `POST /templates/:id/flows`: el nombre violó la validación
/// del dominio (vacío, fuera de longitud) o algún gate (cooldown/usage
/// limit) salió del rango aceptado. Reintentable después de corregir el
/// input — distinto del genérico para que la UI pueda mostrar el copy
/// "Revisa el nombre" en lugar de un error opaco.
final class FlowsInvalidCreateFailure extends FlowsFailure {
  const FlowsInvalidCreateFailure();
}

/// 422 contra mutaciones de step (`POST /flows/:id/steps`, `PATCH
/// /steps/:id`): el body rompió la validación del dominio del step
/// (content vacío en TEXT, delayMs fuera de rango, mediaRef ausente en
/// multimedia, metadata inválida en CONDITIONAL_TIME, etc.). Reintentable
/// tras corregir; copy del cliente debe orientar a "revisa los campos
/// del paso" sin sacar el código del wire.
final class FlowsInvalidStepFailure extends FlowsFailure {
  const FlowsInvalidStepFailure();
}

/// 404 contra mutaciones de step (`PATCH /steps/:id`). Distinto de
/// `FlowsNotFoundFailure` (que es del flow padre) — aquí el flow puede
/// existir pero el step en particular no, típicamente porque otro
/// operador lo borró entre el listado y el patch. Reintentar el mismo
/// id falla idéntico; la UI debe forzar refresh del listado.
final class FlowsStepNotFoundFailure extends FlowsFailure {
  const FlowsStepNotFoundFailure();
}

/// 422 contra `PUT /flows/:id` por settings inválidos: cooldownMs
/// negativo, usageLimit negativo, o un gate fuera del rango aceptado
/// por el dominio. Reintentable tras corregir el input; cubo separado
/// de `FlowsInvalidCreateFailure` para que el copy del Settings tab
/// apunte a "revisa cooldown / límite" sin confundir con el "revisa
/// el nombre" del create.
final class FlowsInvalidSettingsFailure extends FlowsFailure {
  const FlowsInvalidSettingsFailure();
}

/// 409 contra `PUT /flows/:id`: la version observada por el cliente
/// quedó stale (otro operador editó la cabecera) o algún UNIQUE
/// (template_id, name) chocó. Reintentar con la misma version vuelve
/// a fallar — la UI debe pedir recargar el detalle antes de reintentar
/// el guardado.
final class FlowsConflictFailure extends FlowsFailure {
  const FlowsConflictFailure();
}

/// 422 contra `PUT /flows/:id/steps/order`: el array no es permutación
/// exacta de los steps del flow, o el arreglo final dejaría un
/// CONDITIONAL_TIME después de alguno de sus destinos (forward-only).
/// El backend es atómico: nada cambió; la UI restaura la lista y explica.
final class FlowsInvalidReorderFailure extends FlowsFailure {
  const FlowsInvalidReorderFailure();
}

/// 409 contra `DELETE /steps/:id`: el step es destino de un
/// CONDITIONAL_TIME del flow. El operador debe redirigir (o borrar) el
/// condicional antes de poder borrar el destino.
final class FlowsStepReferencedFailure extends FlowsFailure {
  const FlowsStepReferencedFailure();
}
