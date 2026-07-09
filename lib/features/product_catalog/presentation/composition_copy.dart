import '../domain/failures/composition_failure.dart';

/// Copy es-MX de un fallo de composición para las hojas del flujo. Los 422 y
/// 409 traen su mensaje ya traducido desde la frontera de datos; aquí solo
/// se cae al genérico cuando el código no se conoció. JAMÁS un código crudo.
String compositionErrorText(CompositionFailure failure) => switch (failure) {
  CompositionRejectedFailure(:final message) =>
    message ?? 'No se pudo crear. Revisa e inténtalo otra vez.',
  CompositionConflictFailure(:final message) =>
    message ?? 'La acción no procede ahora mismo. Actualiza e intenta.',
  CompositionUnavailableFailure() =>
    'La mejora de fotos no está disponible por ahora. Inténtalo más tarde.',
  CompositionNetworkFailure() =>
    'Sin conexión. Revisa tu red e inténtalo otra vez.',
  CompositionTimeoutFailure() =>
    'La operación tardó demasiado. Inténtalo otra vez.',
  CompositionNotFoundFailure() => 'Eso ya no existe. Actualiza la lista.',
  CompositionServerFailure() ||
  UnknownCompositionFailure() => 'No se pudo completar. Inténtalo otra vez.',
};
