/// Failures expuestos por la capa de datos de Bots.
///
/// Son `Exception` (no `Error`): el llamador es el bloc, que las atrapa y las
/// traduce a estados de UI. La jerarquía es sellada para forzar al switch del
/// bloc a cubrir todos los casos: un failure nuevo rompe el build, no se
/// cuela silencioso.
///
/// 401 NO aparece aquí: lo absorbe el AuthInterceptor (refresh transparente
/// o purga + Unauthenticated). Si llega a este bloc, significa que el access
/// renovado también falló — colapsa a la lógica global de logout vía
/// onUnrecoverable, no a un estado local de la lista.
sealed class BotsFailure implements Exception {
  const BotsFailure();
}

/// Timeout, sin conexión, DNS, TLS. Reintentable por acción del usuario.
final class BotsNetworkFailure extends BotsFailure {
  const BotsNetworkFailure();
}

/// Timeout específico (connect/receive). El interceptor no lo distingue
/// como caso especial; aquí sí porque la UI puede sugerir reintento mejor
/// que un genérico de red.
final class BotsTimeoutFailure extends BotsFailure {
  const BotsTimeoutFailure();
}

/// 403 contra `/bots`: RBAC del backend rechaza el verbo (p. ej. WORKER sin
/// bots asignados que cruza un endpoint ADMIN+). No se reintenta solo —
/// el operador necesita rol distinto o asignación.
final class BotsForbiddenFailure extends BotsFailure {
  const BotsForbiddenFailure();
}

/// 422 contra `POST /bots`: el dominio del backend rechaza la construcción
/// del bot. El handler colapsa varias causas en el mismo status (name
/// vacío vía ErrInvalidBot, channel desconocido vía ErrInvalidChannel,
/// template_id ajeno o inexistente vía ErrTemplateNotFound, variables
/// fuera del set de defs vía ErrVariableNotInDefs). El cliente las agrupa
/// en un solo cubo porque el operador no puede accionar distinto entre
/// ellas sin instrumentación adicional del backend.
final class BotsInvalidCreateFailure extends BotsFailure {
  const BotsInvalidCreateFailure();
}

/// 5xx del backend. Distinto de red: el servidor respondió, pero rompió.
final class BotsServerFailure extends BotsFailure {
  const BotsServerFailure();
}

/// 404 contra `/bots/:id`: el ID no existe en la org activa (o fue borrado).
/// Distinto del 403: aquí el rol alcanza pero el recurso no está. Permite
/// que la UI muestre copy "Este bot ya no existe" en vez de un genérico.
final class BotsNotFoundFailure extends BotsFailure {
  const BotsNotFoundFailure();
}

/// Cualquier otro caso (status no contemplado, body malformado). El cliente
/// lo expone como error genérico sin filtrar el status crudo.
final class UnknownBotsFailure extends BotsFailure {
  const UnknownBotsFailure();
}
