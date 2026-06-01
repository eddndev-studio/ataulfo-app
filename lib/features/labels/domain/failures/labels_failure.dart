/// Failures del catálogo de Labels internos (S10). Son `Exception`; el bloc
/// las traduce a estado de UI. Jerarquía sellada (switch exhaustivo).
///
/// Cubre lectura (`GET /labels`) y mutaciones (`POST`/`PUT`/`DELETE /labels`).
/// 401 lo absorbe el AuthInterceptor.
sealed class LabelsFailure implements Exception {
  const LabelsFailure();
}

final class LabelsNetworkFailure extends LabelsFailure {
  const LabelsNetworkFailure();
}

final class LabelsTimeoutFailure extends LabelsFailure {
  const LabelsTimeoutFailure();
}

/// 403: el rol del operador no alcanza (WORKER+).
final class LabelsForbiddenFailure extends LabelsFailure {
  const LabelsForbiddenFailure();
}

/// 5xx del backend.
final class LabelsServerFailure extends LabelsFailure {
  const LabelsServerFailure();
}

/// 422: el nombre o el color no pasan la validación del backend (nombre vacío
/// o > 50, color que no es `#RRGGBB`, descripción > 280).
final class LabelsValidationFailure extends LabelsFailure {
  const LabelsValidationFailure();
}

/// 409: ya existe una etiqueta con ese nombre en la organización.
final class LabelsDuplicateNameFailure extends LabelsFailure {
  const LabelsDuplicateNameFailure();
}

/// 404: la etiqueta no existe (o es de otra organización) al editar/borrar.
final class LabelsNotFoundFailure extends LabelsFailure {
  const LabelsNotFoundFailure();
}

/// Status no contemplado, body malformado o cast roto.
final class LabelsUnknownFailure extends LabelsFailure {
  const LabelsUnknownFailure();
}
