/// Failures de la capa de datos de Invitations.
///
/// Son `Exception` (no `Error`): el cubit/bloc las atrapan y traducen a estados
/// de UI. Jerarquía sellada para forzar copy exhaustivo. 401 lo absorbe el
/// AuthInterceptor (no aparece aquí).
sealed class InvitationsFailure implements Exception {
  const InvitationsFailure();
}

/// Sin conexión / DNS / TLS. Reintentable.
final class InvitationsNetworkFailure extends InvitationsFailure {
  const InvitationsNetworkFailure();
}

/// Timeout de conexión/envío/recepción.
final class InvitationsTimeoutFailure extends InvitationsFailure {
  const InvitationsTimeoutFailure();
}

/// 403: el subárbol /workspace exige ADMIN+. Defensa de borde (la app oculta el
/// acceso a roles por debajo).
final class InvitationsForbiddenFailure extends InvitationsFailure {
  const InvitationsForbiddenFailure();
}

/// 409 al crear: ya hay una invitación PENDING para ese correo (o ya es
/// miembro). Una PENDING caducada sigue bloqueando hasta cancelarla.
final class InvitationsDuplicateFailure extends InvitationsFailure {
  const InvitationsDuplicateFailure();
}

/// 422 al crear: correo o rol inválidos para el backend.
final class InvitationsValidationFailure extends InvitationsFailure {
  const InvitationsValidationFailure();
}

/// 404 al cancelar: la invitación ya no existe (la lista local quedó stale).
final class InvitationsNotFoundFailure extends InvitationsFailure {
  const InvitationsNotFoundFailure();
}

/// 410 al cancelar: la invitación ya se consumió/expiró del lado servidor y no
/// puede cancelarse (la lista local quedó stale).
final class InvitationsGoneFailure extends InvitationsFailure {
  const InvitationsGoneFailure();
}

/// 5xx del backend. En `create` puede significar que la fila SÍ se guardó pero
/// el correo falló: no asumir que "nada pasó" (no hay endpoint de reenvío).
final class InvitationsServerFailure extends InvitationsFailure {
  const InvitationsServerFailure();
}

/// Cualquier otro caso (status no contemplado, body malformado).
final class UnknownInvitationsFailure extends InvitationsFailure {
  const UnknownInvitationsFailure();
}
