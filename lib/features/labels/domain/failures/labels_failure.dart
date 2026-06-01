/// Failures de la lectura de Labels internos (S10). Son `Exception`; el bloc
/// las traduce a estado de UI. Jerarquía sellada (switch exhaustivo).
///
/// Solo lectura (`GET /labels`): no hay 422/409/502. 401 lo absorbe el
/// AuthInterceptor.
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

/// Status no contemplado, body malformado o cast roto.
final class LabelsUnknownFailure extends LabelsFailure {
  const LabelsUnknownFailure();
}
