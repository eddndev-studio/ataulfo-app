/// Fallos tipados de la superficie del entrenador (workspace + hilos +
/// preview). Una sola familia sellada: las tres áreas comparten wire y el
/// copy de la UI ramifica por tipo, no por endpoint.
sealed class TrainerFailure implements Exception {
  const TrainerFailure();
}

/// 409 — CAS perdido (otro editor —operador, IA o panel— cambió el texto)
/// o nombre duplicado al crear un doc.
final class TrainerConflictFailure extends TrainerFailure {
  const TrainerConflictFailure();
}

/// 422 — payload rechazado por reglas de dominio (slug inválido, caps).
final class TrainerValidationFailure extends TrainerFailure {
  const TrainerValidationFailure();
}

/// 404 — plantilla/doc/hilo fuera de la org o inexistente.
final class TrainerNotFoundFailure extends TrainerFailure {
  const TrainerNotFoundFailure();
}

/// 403 — RBAC (el wire entero es ADMIN+).
final class TrainerForbiddenFailure extends TrainerFailure {
  const TrainerForbiddenFailure();
}

/// 502 — el motor IA no produjo turno (provider caído, timeout del run).
final class TrainerEngineFailure extends TrainerFailure {
  const TrainerEngineFailure();
}

/// 503 — capacidad sin cablear en el server (sandbox/IA sin API keys).
final class TrainerUnavailableFailure extends TrainerFailure {
  const TrainerUnavailableFailure();
}

final class TrainerNetworkFailure extends TrainerFailure {
  const TrainerNetworkFailure();
}

final class TrainerTimeoutFailure extends TrainerFailure {
  const TrainerTimeoutFailure();
}

final class TrainerServerFailure extends TrainerFailure {
  const TrainerServerFailure();
}

final class TrainerUnknownFailure extends TrainerFailure {
  const TrainerUnknownFailure();
}
