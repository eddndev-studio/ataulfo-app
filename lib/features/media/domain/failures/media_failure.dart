/// Failures de la capa de datos de Media (`POST /upload`, `GET /media-assets`).
///
/// Son `Exception` (no `Error`): las atrapa el bloc y las traduce a estados de
/// UI. Jerarquía sellada para forzar el switch a cubrir todos los casos — un
/// failure nuevo rompe el build, no se cuela. Sin `==` propio: marcadores const
/// sin campos, canonicalizados por Dart, suficiente para la igualdad de estados
/// del bloc.
///
/// 401 NO aparece aquí: lo absorbe el AuthInterceptor (refresh transparente o
/// purga + Unauthenticated). Si un 401 llega final (refresh agotado), colapsa a
/// Unknown — el operador no acciona distinto a otro estado terminal.
sealed class MediaFailure implements Exception {
  const MediaFailure();
}

/// Sin conexión, DNS, TLS. Reintentable por acción del usuario.
final class MediaNetworkFailure extends MediaFailure {
  const MediaNetworkFailure();
}

/// Timeout connect/receive/send. La subida de un archivo grande puede agotar
/// el send timeout; la UI sugiere reintento mejor que un genérico de red.
final class MediaTimeoutFailure extends MediaFailure {
  const MediaTimeoutFailure();
}

/// 403: el RBAC del backend rechaza el verbo (sin claim WORKER+).
final class MediaForbiddenFailure extends MediaFailure {
  const MediaForbiddenFailure();
}

/// 404: el recurso no existe (no esperado en el listado normal; reservado para
/// completitud del mapeo de status).
final class MediaNotFoundFailure extends MediaFailure {
  const MediaNotFoundFailure();
}

/// 413: el archivo excede el tamaño máximo permitido por el backend.
final class MediaTooLargeFailure extends MediaFailure {
  const MediaTooLargeFailure();
}

/// 415: el tipo de contenido del archivo no está permitido.
final class MediaUnsupportedTypeFailure extends MediaFailure {
  const MediaUnsupportedTypeFailure();
}

/// 5xx: el servidor respondió pero rompió. Distinto de red.
final class MediaServerFailure extends MediaFailure {
  const MediaServerFailure();
}

/// Status no contemplado (incl. 400 form/cursor inválido, 401 final) o body
/// malformado. Se expone como error genérico sin filtrar el status crudo.
final class UnknownMediaFailure extends MediaFailure {
  const UnknownMediaFailure();
}
