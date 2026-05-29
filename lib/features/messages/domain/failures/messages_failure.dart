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

/// Status no contemplado (incl. 409) o body malformado. Se expone como error
/// genérico sin filtrar el status crudo.
final class UnknownMessagesFailure extends MessagesFailure {
  const UnknownMessagesFailure();
}
