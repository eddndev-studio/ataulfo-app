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

/// 409 contra `PUT /bots/:id`: conflicto de versión (CAS). La `version`
/// enviada quedó atrás respecto a la del servidor — otra edición ganó la
/// carrera. La UI refresca el snapshot y ofrece reintentar.
///
/// NOTA sobre el 409 sobrecargado: el mismo status lo emite `RequireActiveOrg`
/// cuando el Bearer no trae org activa, ANTES de llegar al handler. Como este
/// cliente no modela switch-org (el org activo viaja baqueado en el token),
/// ese caso es inalcanzable post-login y el cliente interpreta el 409 del PUT
/// como conflicto de versión. El mapeo es POR-ENDPOINT: sólo el PUT lo traduce
/// a este failure; en otros verbos (create) un 409 colapsa a `UnknownBotsFailure`.
final class BotsConflictFailure extends BotsFailure {
  const BotsConflictFailure();
}

/// 409 contra `clear-conversations` / `reset-sessions`: el bot no está pausado
/// (`ErrBotNotPaused`). Estas ops de runtime exigen `paused=true`. La UI las
/// deshabilita cuando `!paused`; este failure es la red de seguridad si el
/// estado quedó stale. Mapeo POR-ENDPOINT: sólo clear/reset traducen 409 a
/// este failure (otros verbos de sesión colapsan su 409 a genérico).
final class BotsNotPausedFailure extends BotsFailure {
  const BotsNotPausedFailure();
}

/// 409 contra `POST /bots/:id/session/pair-phone`: el emparejamiento no está
/// iniciado (`ErrNotRunning` — faltó el `POST /session` previo, o la sesión ya
/// cayó). El operador acciona iniciando el emparejamiento primero. Mapeo
/// POR-ENDPOINT: sólo pair-phone traduce su 409 a este failure (la otra causa
/// del status, org ausente en claims, es inalcanzable post-login — mismo
/// razonamiento que `BotsConflictFailure`).
final class BotsPairingNotStartedFailure extends BotsFailure {
  const BotsPairingNotStartedFailure();
}

/// 400/422 contra `POST /bots/:id/session/pair-phone`: el teléfono no fue
/// aceptado. El backend colapsa varias causas en el 422 (número corto, cero
/// inicial, device ya emparejado, IQ rechazado, timeout del wire) con cuerpo
/// opaco; el 400 sólo ocurre con phone vacío — la validación local lo
/// previene, así que agruparlo aquí es honesto. Mapeo POR-ENDPOINT: sólo
/// pair-phone traduce 400/422 a este failure.
final class BotsPhoneRejectedFailure extends BotsFailure {
  const BotsPhoneRejectedFailure();
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
