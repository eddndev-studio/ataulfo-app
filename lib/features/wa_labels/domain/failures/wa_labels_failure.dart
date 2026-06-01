/// Failures expuestos por la capa de datos de etiquetas WhatsApp (S21).
///
/// Son `Exception` (no `Error`): el llamador es el bloc, que las atrapa y las
/// traduce a estados de UI. Jerarquía sellada para forzar al switch del bloc a
/// cubrir todos los casos.
///
/// 401 NO aparece aquí: lo absorbe el AuthInterceptor (refresh transparente o
/// purga + Unauthenticated).
///
/// Dos failures son propias de este dominio (empujar a WhatsApp puede fallar de
/// formas que el resto de los recursos no tienen):
///   - [WaLabelsNotConnectedFailure] (409): el bot no está corriendo / su
///     app-state aún no sincroniza, así que no se puede empujar la edición.
///   - [WaLabelsUpstreamFailure] (502): WhatsApp rechazó o no respondió el push.
/// Ambas solo aparecen en mutaciones que empujan al cliente WhatsApp (CRUD del
/// catálogo, asociar/desasociar). El mapeo a Label interno NO empuja: nunca las
/// produce.
sealed class WaLabelsFailure implements Exception {
  const WaLabelsFailure();
}

/// Timeout, sin conexión, DNS, TLS. Reintentable por acción del usuario.
final class WaLabelsNetworkFailure extends WaLabelsFailure {
  const WaLabelsNetworkFailure();
}

/// Timeout específico (connect/receive). Distinto del genérico de red para que
/// la UI pueda sugerir reintento con copy más útil.
final class WaLabelsTimeoutFailure extends WaLabelsFailure {
  const WaLabelsTimeoutFailure();
}

/// 403: el rol del operador no alcanza (WORKER+ según S21). No se reintenta solo.
final class WaLabelsForbiddenFailure extends WaLabelsFailure {
  const WaLabelsForbiddenFailure();
}

/// 404: el bot no existe en la org del operador (o fue borrado). Reintentar el
/// mismo id volverá a fallar — estado terminal sin retry automático.
final class WaLabelsNotFoundFailure extends WaLabelsFailure {
  const WaLabelsNotFoundFailure();
}

/// 5xx del backend (no upstream): el servidor respondió pero rompió.
final class WaLabelsServerFailure extends WaLabelsFailure {
  const WaLabelsServerFailure();
}

/// Cualquier otro caso (status no contemplado, body malformado, cast roto). El
/// cliente lo expone como error genérico sin filtrar el status crudo.
final class WaLabelsUnknownFailure extends WaLabelsFailure {
  const WaLabelsUnknownFailure();
}

/// 422: el body rompió la validación del backend (nombre vacío, kind inválido,
/// messageId vacío, o — en el mapeo — un `labelId` vacío o que no existe en la
/// org del bot). El call site interpreta el copy según el contexto.
final class WaLabelsInvalidFailure extends WaLabelsFailure {
  const WaLabelsInvalidFailure();
}

/// 409: el bot no está conectado a WhatsApp (o su app-state aún no sincroniza),
/// así que el push de la edición no pudo ejecutarse. La UI sugiere reconectar
/// el bot antes de reintentar.
final class WaLabelsNotConnectedFailure extends WaLabelsFailure {
  const WaLabelsNotConnectedFailure();
}

/// 502: WhatsApp (upstream) rechazó o no respondió el push. Distinto de un 5xx
/// del propio backend: el fallo está aguas arriba, en el cliente de WhatsApp.
final class WaLabelsUpstreamFailure extends WaLabelsFailure {
  const WaLabelsUpstreamFailure();
}
