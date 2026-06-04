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

/// 409 en una mutación: la acción dejaría a la organización sin ningún OWNER
/// (degradar o quitar al único dueño). Distinto de NoActiveOrg, que es el otro
/// 409 del subárbol (el del listado) — por eso el mapeo es por-método.
final class MembersSoleOwnerFailure extends MembersFailure {
  const MembersSoleOwnerFailure();
}

/// 403 en change-role: el caller intenta ascender su propio rol. Es el único
/// 403 a nivel de servicio para esa mutación (self-demote sí se permite).
final class MembersSelfRoleUpgradeFailure extends MembersFailure {
  const MembersSelfRoleUpgradeFailure();
}

/// 404 en una mutación: el miembro objetivo ya no existe (la lista del cliente
/// quedó desfasada respecto al servidor).
final class MembersNotFoundFailure extends MembersFailure {
  const MembersNotFoundFailure();
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
