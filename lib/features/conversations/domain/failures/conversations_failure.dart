/// Failures de la capa de datos de Conversaciones (listado de sesiones S07).
///
/// Son `Exception` (no `Error`): las atrapa el bloc y las traduce a estados de
/// UI. Jerarquía sellada para forzar el switch a cubrir todos los casos — un
/// failure nuevo rompe el build, no se cuela. Sin `==` propio: son marcadores
/// const sin campos, canonicalizados por Dart (dos instancias const son
/// idénticas), suficiente para la igualdad de estados del bloc.
///
/// 401 NO aparece aquí: lo absorbe el AuthInterceptor (refresh transparente o
/// purga + Unauthenticated). 409 (sin org activa) colapsa a Unknown: en flujo
/// normal post-login no ocurre y el operador no acciona distinto.
sealed class ConversationsFailure implements Exception {
  const ConversationsFailure();
}

/// Sin conexión, DNS, TLS. Reintentable por acción del usuario.
final class ConversationsNetworkFailure extends ConversationsFailure {
  const ConversationsNetworkFailure();
}

/// Timeout connect/receive/send. La UI sugiere reintento mejor que un
/// genérico de red.
final class ConversationsTimeoutFailure extends ConversationsFailure {
  const ConversationsTimeoutFailure();
}

/// 403: el RBAC del backend rechaza el verbo sobre `/sessions/:botId`.
final class ConversationsForbiddenFailure extends ConversationsFailure {
  const ConversationsForbiddenFailure();
}

/// 404: el bot no existe en la org activa (o fue borrado). El endpoint
/// autoriza por propiedad del bot; un 404 es del bot, no de una conversación.
/// Permite copy "Este bot ya no existe" en vez de un genérico.
final class ConversationsNotFoundFailure extends ConversationsFailure {
  const ConversationsNotFoundFailure();
}

/// 5xx: el servidor respondió pero rompió. Distinto de red.
final class ConversationsServerFailure extends ConversationsFailure {
  const ConversationsServerFailure();
}

/// 422: filtro o cursor inválido/obsoleto. Un cursor queda ligado al conjunto
/// de filtros, por lo que la recuperación correcta es reiniciar la página.
final class ConversationsInvalidQueryFailure extends ConversationsFailure {
  const ConversationsInvalidQueryFailure();
}

/// Status no contemplado (incl. 409 sin org activa) o body malformado. Se
/// expone como error genérico sin filtrar el status crudo.
final class UnknownConversationsFailure extends ConversationsFailure {
  const UnknownConversationsFailure();
}
