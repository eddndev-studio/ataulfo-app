/// Failures expuestos por la capa de datos de Members.
///
/// Son `Exception` (no `Error`): el bloc las atrapa y traduce a estados de
/// UI. La jerarquía es sellada para forzar al switch del bloc a cubrir todos
/// los casos: una failure nueva rompe el build, no se cuela silenciosa.
///
/// 401 NO aparece aquí: lo absorbe el AuthInterceptor (refresh transparente o
/// purga + Unauthenticated). Si llegara a este bloc, colapsa a la lógica
/// global de logout, no a un estado local del listado.
sealed class MembersFailure implements Exception {
  const MembersFailure();
}

/// Sin conexión, DNS, TLS, connection error. Reintentable por acción del
/// usuario.
final class MembersNetworkFailure extends MembersFailure {
  const MembersNetworkFailure();
}

/// Timeout específico (connect/send/receive). Distinto de network para que la
/// UI pueda matizar el tono del reintento.
final class MembersTimeoutFailure extends MembersFailure {
  const MembersTimeoutFailure();
}

/// 403 contra `/workspace/members`: el subárbol exige ADMIN+ y el backend
/// rechaza a roles por debajo. La app oculta el acceso a esos roles, así que
/// es una defensa de borde; se tipa explícito para no esconderla en Unknown.
final class MembersForbiddenFailure extends MembersFailure {
  const MembersForbiddenFailure();
}

/// 409: el caller no tiene org activa (guard RequireActiveOrg). En la app el
/// router desvía ese estado a la selección de organización antes de montar la
/// página, pero el contrato se mapea igual por completitud.
final class MembersNoActiveOrgFailure extends MembersFailure {
  const MembersNoActiveOrgFailure();
}

/// 5xx del backend. Distinto de red: el servidor respondió, pero rompió.
final class MembersServerFailure extends MembersFailure {
  const MembersServerFailure();
}

/// Cualquier otro caso (status no contemplado, body malformado). El cliente lo
/// expone como error genérico sin filtrar el status crudo.
final class UnknownMembersFailure extends MembersFailure {
  const UnknownMembersFailure();
}
