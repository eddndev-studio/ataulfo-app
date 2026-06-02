/// Gateo de privilegio de cliente derivado del rol org-scoped (`Identity.role`).
///
/// Espeja el guard `adminOnly` del backend (`RequireRole(RoleAdmin)` =
/// `AtLeast(RoleAdmin)`): toda mutación de Bot y operación de sesión exige
/// ADMIN o superior. Con la jerarquía OWNER > ADMIN > SUPERVISOR > WORKER,
/// "Admin o superior" es exactamente {ADMIN, OWNER}. SUPERVISOR queda por
/// debajo de ADMIN y el backend lo rechaza con 403 en esos endpoints, así
/// que el cliente le oculta los controles en vez de ofrecer botones que
/// siempre fallan.
///
/// Es gateo COSMÉTICO: la autoridad real sigue siendo el 403/404 del backend.
/// Por eso es fail-closed — un rol desconocido (drift de contrato, casing
/// inesperado, vacío) NO concede privilegio.
bool isAdminOrAbove(String role) => switch (role) {
  'OWNER' || 'ADMIN' => true,
  _ => false,
};
