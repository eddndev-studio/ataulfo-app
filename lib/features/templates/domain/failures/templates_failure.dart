/// Failures expuestos por la capa de datos de Templates (S03).
///
/// Son `Exception` (no `Error`): el llamador es el bloc, que las atrapa y
/// las traduce a estados de UI. La jerarquía es sellada para forzar al
/// switch del bloc a cubrir todos los casos: un failure nuevo rompe el
/// build, no se cuela silencioso.
///
/// 401 NO aparece aquí: lo absorbe el AuthInterceptor (refresh transparente
/// o purga + Unauthenticated). Si llega a este bloc, significa que el
/// access renovado también falló — colapsa a la lógica global de logout
/// vía onUnrecoverable, no a un estado local de la lista.
///
/// NotFound NO aparece en este slice: `GET /templates` responde 200 con
/// `[]` cuando la org no tiene templates, nunca 404. La variante se sumará
/// con el endpoint de detalle por id en un slice posterior.
sealed class TemplatesFailure implements Exception {
  const TemplatesFailure();
}

/// Timeout, sin conexión, DNS, TLS. Reintentable por acción del usuario.
final class TemplatesNetworkFailure extends TemplatesFailure {
  const TemplatesNetworkFailure();
}

/// Timeout específico (connect/receive). Distinto del genérico de red
/// para que la UI pueda sugerir reintento con copy más útil.
final class TemplatesTimeoutFailure extends TemplatesFailure {
  const TemplatesTimeoutFailure();
}

/// 403 contra `/templates`: el rol del operador no alcanza para el verbo
/// (CRUD de Template = ADMIN+ según S03). No se reintenta solo.
final class TemplatesForbiddenFailure extends TemplatesFailure {
  const TemplatesForbiddenFailure();
}

/// 5xx del backend. El servidor respondió pero rompió — distinto de red.
final class TemplatesServerFailure extends TemplatesFailure {
  const TemplatesServerFailure();
}

/// Cualquier otro caso (status no contemplado, body malformado). El
/// cliente lo expone como error genérico sin filtrar el status crudo.
final class UnknownTemplatesFailure extends TemplatesFailure {
  const UnknownTemplatesFailure();
}
