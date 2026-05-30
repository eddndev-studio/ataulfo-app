/// Failures de la capa de datos del perfil de un chat (GET .../profile).
///
/// `Exception` sellada (no `Error`): el bloc las atrapa y traduce a estados de
/// UI; el switch exhaustivo rompe el build si se agrega un caso. Marcadores
/// const sin campos (canonicalizados por Dart), suficiente para la igualdad de
/// estados. 401 lo absorbe el AuthInterceptor; 409 colapsa a Unknown.
sealed class ProfileFailure implements Exception {
  const ProfileFailure();
}

/// Sin conexión, DNS, TLS. Reintentable por acción del usuario.
final class ProfileNetworkFailure extends ProfileFailure {
  const ProfileNetworkFailure();
}

/// Timeout connect/receive/send.
final class ProfileTimeoutFailure extends ProfileFailure {
  const ProfileTimeoutFailure();
}

/// 403: el RBAC del backend rechaza el verbo.
final class ProfileForbiddenFailure extends ProfileFailure {
  const ProfileForbiddenFailure();
}

/// 404: el bot o la conversación no existen en la org activa.
final class ProfileNotFoundFailure extends ProfileFailure {
  const ProfileNotFoundFailure();
}

/// 5xx: el servidor respondió pero rompió.
final class ProfileServerFailure extends ProfileFailure {
  const ProfileServerFailure();
}

/// Status no contemplado o body malformado.
final class UnknownProfileFailure extends ProfileFailure {
  const UnknownProfileFailure();
}
