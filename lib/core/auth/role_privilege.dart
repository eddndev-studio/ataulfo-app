/// Gateo de privilegio de cliente derivado del rol org-scoped (`Identity.role`).
///
/// La jerarquía organizacional es OWNER > ADMIN > SUPERVISOR > WORKER. Los
/// helpers de este archivo reflejan las bandas de capacidades del backend para
/// ocultar superficies que terminarían en 403.
///
/// Es gateo COSMÉTICO: la autoridad real sigue siendo el 403/404 del backend.
/// Por eso es fail-closed — un rol desconocido (drift de contrato, casing
/// inesperado, vacío) NO concede privilegio.
bool isAdminOrAbove(String role) => switch (role) {
  'OWNER' || 'ADMIN' => true,
  _ => false,
};

/// Herramientas globales de operación: agenda, medios, catálogo, recursos,
/// notas, cuenta de la organización y Ataúlfo. Un WORKER sólo opera los
/// Canales asignados; cualquier literal desconocido se rechaza.
bool isSupervisorOrAbove(String role) => switch (role) {
  'OWNER' || 'ADMIN' || 'SUPERVISOR' => true,
  _ => false,
};
