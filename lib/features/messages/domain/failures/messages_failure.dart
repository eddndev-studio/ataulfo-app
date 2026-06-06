/// Failures de la capa de datos del hilo de mensajes (S09 `GET
/// /sessions/:botId/:chatLid/messages`).
///
/// Son `Exception` (no `Error`): las atrapa el bloc y las traduce a estados de
/// UI. Jerarquía sellada para forzar el switch exhaustivo. Sin `==` propio:
/// marcadores const sin campos, canonicalizados por Dart.
///
/// 401 NO aparece: lo absorbe el AuthInterceptor. 409 (sin org activa) colapsa
/// a Unknown (no ocurre en flujo normal post-login). Un hilo vacío NO es un
/// failure: es un estado legítimo (200 con `messages: []`).
sealed class MessagesFailure implements Exception {
  const MessagesFailure();
}

/// Sin conexión, DNS, TLS. Reintentable por acción del usuario.
final class MessagesNetworkFailure extends MessagesFailure {
  const MessagesNetworkFailure();
}

/// Timeout connect/receive/send.
final class MessagesTimeoutFailure extends MessagesFailure {
  const MessagesTimeoutFailure();
}

/// 403: el RBAC del backend rechaza el verbo sobre el hilo.
final class MessagesForbiddenFailure extends MessagesFailure {
  const MessagesForbiddenFailure();
}

/// 404: el bot no existe en la org activa. El endpoint autoriza por propiedad
/// del bot; una sesión inexistente NO da 404 (da 200 vacío), así que un 404
/// es siempre del bot.
final class MessagesNotFoundFailure extends MessagesFailure {
  const MessagesNotFoundFailure();
}

/// 5xx: el servidor respondió pero rompió. Distinto de red.
final class MessagesServerFailure extends MessagesFailure {
  const MessagesServerFailure();
}

/// 409 en el path de escritura: conflicto de idempotencia (misma `clientToken`
/// con contenido distinto) — un reintento con otro cuerpo bajo la misma token.
/// No ocurre en `thread` (GET), donde 409 = sin org activa y colapsa a Unknown.
final class MessagesConflictFailure extends MessagesFailure {
  const MessagesConflictFailure();
}

/// 422 en escritura: el cuerpo no pasa validación (texto sin `content`, imagen
/// sin `mediaRef`/ref que no califica, JSON malformado).
final class MessagesValidationFailure extends MessagesFailure {
  const MessagesValidationFailure();
}

/// 423 Locked: el bot está pausado. El operador lo silenció; el wire no se toca
/// hasta reanudarlo. Aplica a send/react/mark-read (gate `ownedActiveBot`).
final class MessagesBotPausedFailure extends MessagesFailure {
  const MessagesBotPausedFailure();
}

/// 503: el bot no tiene sesión corriendo (no conectado). Reintentable tras
/// reconectar.
final class MessagesNotConnectedFailure extends MessagesFailure {
  const MessagesNotConnectedFailure();
}

/// 502: el proveedor (wire de WhatsApp) rechazó o falló la operación. Distinto
/// de un 5xx propio del backend.
final class MessagesWireFailure extends MessagesFailure {
  const MessagesWireFailure();
}

/// Status no contemplado (incl. 409) o body malformado. Se expone como error
/// genérico sin filtrar el status crudo.
final class UnknownMessagesFailure extends MessagesFailure {
  const UnknownMessagesFailure();
}
