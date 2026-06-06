/// Failures expuestos por la capa de datos de respuestas rápidas WhatsApp (S23).
///
/// Son `Exception` (no `Error`): el llamador es el bloc, que las atrapa y las
/// traduce a estados de UI. Jerarquía sellada para forzar al switch del consumidor
/// a cubrir todos los casos.
///
/// El recurso es de SOLO LECTURA (`GET /bots/{botId}/quick-replies`): no hay push
/// a WhatsApp, así que NO aparecen los failures de mutación de las etiquetas
/// (NotConnected/Upstream/Invalid). 401 tampoco aparece: lo absorbe el
/// AuthInterceptor (refresh transparente o purga + Unauthenticated).
sealed class QuickRepliesFailure implements Exception {
  const QuickRepliesFailure();
}

/// Timeout, sin conexión, DNS, TLS. Reintentable por acción del usuario.
final class QuickRepliesNetworkFailure extends QuickRepliesFailure {
  const QuickRepliesNetworkFailure();
}

/// Timeout específico (connect/receive). Distinto del genérico de red para que
/// la UI pueda sugerir reintento con copy más útil.
final class QuickRepliesTimeoutFailure extends QuickRepliesFailure {
  const QuickRepliesTimeoutFailure();
}

/// 403: el rol del operador no alcanza (WORKER+ según S23). No se reintenta solo.
final class QuickRepliesForbiddenFailure extends QuickRepliesFailure {
  const QuickRepliesForbiddenFailure();
}

/// 404: el bot no existe en la org del operador (o fue borrado). Reintentar el
/// mismo id volverá a fallar — estado terminal sin retry automático.
final class QuickRepliesNotFoundFailure extends QuickRepliesFailure {
  const QuickRepliesNotFoundFailure();
}

/// 5xx del backend: el servidor respondió pero rompió.
final class QuickRepliesServerFailure extends QuickRepliesFailure {
  const QuickRepliesServerFailure();
}

/// Cualquier otro caso (status no contemplado, body malformado, cast roto). El
/// cliente lo expone como error genérico sin filtrar el status crudo.
final class QuickRepliesUnknownFailure extends QuickRepliesFailure {
  const QuickRepliesUnknownFailure();
}
