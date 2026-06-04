/// Failures de autenticación expuestas por la capa de datos.
///
/// Son `Exception` (no `Error`): el llamador es el bloc, que las atrapa y
/// las traduce a estados de UI. La jerarquía es sellada para forzar al
/// switch del bloc a cubrir todos los casos: un failure nuevo rompe el
/// build, no se cuela silencioso.
sealed class AuthFailure implements Exception {
  const AuthFailure();
}

/// 401 contra `/auth/login`: credenciales incorrectas.
final class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure();
}

/// 429 contra `/auth/login`: rate limit (S02 RF#9). El cliente debe
/// reintentar tras un backoff (mensaje "intenta en un momento").
final class RateLimitedFailure extends AuthFailure {
  const RateLimitedFailure();
}

/// Timeout, sin conexión, DNS, TLS. Reintentable por acción del usuario.
final class NetworkFailure extends AuthFailure {
  const NetworkFailure();
}

/// 409 contra `/auth/register`: el email ya tiene cuenta. El cliente invita
/// a iniciar sesión en vez de re-registrarse.
final class EmailTakenFailure extends AuthFailure {
  const EmailTakenFailure();
}

/// 400 contra `/auth/register` o `/auth/reset-password`: la contraseña no
/// cumple la política mínima del backend (longitud/complejidad).
final class WeakPasswordFailure extends AuthFailure {
  const WeakPasswordFailure();
}

/// 404 contra los endpoints que canjean un token de un solo uso
/// (verificación de email, reset, invitación): el token no existe o ya se
/// consumió. El cliente pide reiniciar el flujo (re-enviar/re-solicitar).
final class InvalidTokenFailure extends AuthFailure {
  const InvalidTokenFailure();
}

/// 410 contra esos mismos endpoints: el token existió pero su ventana de
/// validez expiró. Distinto de `InvalidToken` para que la UI ofrezca el
/// copy correcto ("el enlace caducó, solicita uno nuevo").
final class ExpiredTokenFailure extends AuthFailure {
  const ExpiredTokenFailure();
}

/// 409 contra `/auth/accept-invitation`: la invitación se emitió para un
/// email distinto al de la sesión actual. El operador inició sesión con la
/// cuenta equivocada para esa invitación.
final class EmailMismatchFailure extends AuthFailure {
  const EmailMismatchFailure();
}

/// 409 contra `/auth/accept-invitation`: el usuario ya es miembro de la org
/// de la invitación. Aceptar es no-op; el cliente lo trata como informativo.
final class AlreadyMemberFailure extends AuthFailure {
  const AlreadyMemberFailure();
}

/// 403 contra `/auth/switch-org`: el usuario no es miembro de la org a la
/// que intenta cambiar (membership revocada o id ajeno). El cliente refresca
/// la lista de orgs en vez de insistir.
final class NotMemberFailure extends AuthFailure {
  const NotMemberFailure();
}

/// Cualquier otro status (5xx, body malformado, etc.). El backend o el
/// transporte rompieron de forma no contemplada — el cliente lo expone
/// como error genérico sin filtrar el status crudo.
final class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure();
}
