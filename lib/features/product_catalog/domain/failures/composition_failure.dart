/// Failures de la composición de fondos (mejorar foto con IA).
///
/// Son `Exception` (no `Error`): los cubits las atrapan y traducen a estados
/// de UI. Jerarquía sellada: un failure nuevo rompe el build, no se cuela
/// silencioso. 401 NO aparece (lo absorbe el AuthInterceptor).
sealed class CompositionFailure implements Exception {
  const CompositionFailure();
}

/// Sin conexión, DNS, TLS, connection error. Reintentable.
final class CompositionNetworkFailure extends CompositionFailure {
  const CompositionNetworkFailure();
}

/// Timeout específico (connect/send/receive).
final class CompositionTimeoutFailure extends CompositionFailure {
  const CompositionTimeoutFailure();
}

/// 404: el producto o el job no existen en la org del operador.
final class CompositionNotFoundFailure extends CompositionFailure {
  const CompositionNotFoundFailure();
}

/// 503: el dominio de imagen no está disponible ahora mismo. Distinto del
/// 5xx genérico para poder decir «inténtalo más tarde» sin alarmar.
final class CompositionUnavailableFailure extends CompositionFailure {
  const CompositionUnavailableFailure();
}

/// 422: el backend rechazó la petición por su dominio (sin foto original,
/// cuota agotada, modelo fuera del plan, suscripción caída…). El código
/// estable del wire se traduce a copy es-MX en [message]; null si el código
/// no se conoce (la UI cae a su copy genérico).
final class CompositionRejectedFailure extends CompositionFailure {
  const CompositionRejectedFailure([this.message]);

  final String? message;

  @override
  bool operator ==(Object other) =>
      other is CompositionRejectedFailure && other.message == message;

  @override
  int get hashCode => Object.hash(CompositionRejectedFailure, message);
}

/// 409: la acción no procede en el estado actual del job (aceptar sin
/// terminar, descartar en vuelo o con la imagen en uso). Mismo contrato de
/// [message] que el 422.
final class CompositionConflictFailure extends CompositionFailure {
  const CompositionConflictFailure([this.message]);

  final String? message;

  @override
  bool operator ==(Object other) =>
      other is CompositionConflictFailure && other.message == message;

  @override
  int get hashCode => Object.hash(CompositionConflictFailure, message);
}

/// 5xx del backend (salvo 503). El servidor respondió, pero rompió.
final class CompositionServerFailure extends CompositionFailure {
  const CompositionServerFailure();
}

/// Cualquier otro caso (status no contemplado, body malformado, type error).
final class UnknownCompositionFailure extends CompositionFailure {
  const UnknownCompositionFailure();
}
