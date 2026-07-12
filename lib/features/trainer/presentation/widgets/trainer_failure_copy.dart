import '../../domain/failures/trainer_failure.dart';

/// Copy por tipo de fallo, compartido por las tres pantallas del entrenador.
String trainerFailureCopy(TrainerFailure f) => switch (f) {
  TrainerEngineFailure() =>
    'El motor IA no pudo completar el turno. Intenta de nuevo.',
  TrainerUnavailableFailure() =>
    'Esta capacidad no está habilitada en el servidor.',
  TrainerConflictFailure() =>
    'Otro editor (el panel o el entrenador) cambió esto al mismo tiempo. Recarga e intenta de nuevo.',
  TrainerValidationFailure() =>
    'El contenido no pasó las reglas (revisa nombre/tamaño).',
  TrainerAttachmentTooLargeFailure() =>
    'El archivo pesa demasiado (máx 25 MB).',
  TrainerAttachmentUnsupportedFailure() =>
    'Tipo no soportado (imagen JPG/PNG/WebP, video MP4 o PDF).',
  TrainerAttachmentLimitFailure() =>
    'Puedes adjuntar hasta 5 archivos por turno.',
  TrainerNotFoundFailure() => 'Eso ya no existe.',
  TrainerForbiddenFailure() => 'Necesitas rol ADMIN para esto.',
  TrainerNetworkFailure() => 'Sin conexión con el servidor.',
  TrainerTimeoutFailure() => 'La operación tardó demasiado.',
  TrainerServerFailure() => 'Error del servidor. Intenta más tarde.',
  TrainerUnknownFailure() => 'Algo salió mal.',
};
