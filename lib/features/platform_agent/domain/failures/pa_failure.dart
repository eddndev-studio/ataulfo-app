/// Fallos tipados de la superficie del asistente de plataforma. Una sola
/// familia sellada: el copy de la UI ramifica por tipo, no por endpoint.
sealed class PaFailure implements Exception {
  const PaFailure();
}

/// 409 — conflicto de versión (otro escritor avanzó la entidad).
final class PaConflictFailure extends PaFailure {
  const PaConflictFailure();
}

/// 422 — payload rechazado por reglas de dominio (title oversize, args).
final class PaValidationFailure extends PaFailure {
  const PaValidationFailure();
}

/// 413 (o rechazo client-side previo a subir): el adjunto excede el tope de
/// tamaño por archivo.
final class PaAttachmentTooLargeFailure extends PaFailure {
  const PaAttachmentTooLargeFailure();
}

/// 415 — el server rechazó el tipo del adjunto (fuera de la allowlist
/// imagen/PDF).
final class PaAttachmentUnsupportedFailure extends PaFailure {
  const PaAttachmentUnsupportedFailure();
}

/// Rechazo client-side: el lote superaría el máximo de adjuntos por turno.
final class PaAttachmentLimitFailure extends PaFailure {
  const PaAttachmentLimitFailure();
}

/// 404 — hilo fuera de la org / de otro operador / inexistente.
final class PaNotFoundFailure extends PaFailure {
  const PaNotFoundFailure();
}

/// 403 — RBAC (rol insuficiente para la operación).
final class PaForbiddenFailure extends PaFailure {
  const PaForbiddenFailure();
}

/// 502 — el motor IA no produjo turno (provider caído, timeout, max iter).
final class PaEngineFailure extends PaFailure {
  const PaEngineFailure();
}

/// 503 — capacidad sin cablear en el server (motor sin API keys).
final class PaUnavailableFailure extends PaFailure {
  const PaUnavailableFailure();
}

final class PaNetworkFailure extends PaFailure {
  const PaNetworkFailure();
}

final class PaTimeoutFailure extends PaFailure {
  const PaTimeoutFailure();
}

final class PaServerFailure extends PaFailure {
  const PaServerFailure();
}

final class PaUnknownFailure extends PaFailure {
  const PaUnknownFailure();
}
