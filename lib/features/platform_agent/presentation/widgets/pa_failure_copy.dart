import '../../domain/failures/pa_failure.dart';

/// Copy en español por tipo de fallo del asistente de plataforma.
String platformAgentFailureCopy(PaFailure f) => switch (f) {
  PaEngineFailure() =>
    'El asistente no pudo completar el turno. Intenta de nuevo.',
  PaUnavailableFailure() => 'El asistente no está habilitado en el servidor.',
  PaConflictFailure() =>
    'Otro cambio ocurrió al mismo tiempo. Vuelve a intentarlo.',
  PaValidationFailure() => 'El mensaje no pasó las reglas del servidor.',
  PaNotFoundFailure() => 'Esta conversación ya no existe.',
  PaForbiddenFailure() => 'No tienes permiso para esta acción.',
  PaNetworkFailure() => 'Sin conexión con el servidor.',
  PaTimeoutFailure() => 'La operación tardó demasiado.',
  PaServerFailure() => 'Error del servidor. Intenta más tarde.',
  PaUnknownFailure() => 'Algo salió mal.',
};
