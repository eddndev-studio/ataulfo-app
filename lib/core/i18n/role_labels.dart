/// Traducciones de los identificadores de wire (roles y estados de
/// invitación) al copy humano de la UI. SOLO para display: los valores que
/// viajan, se comparan o se envían siguen siendo los crudos del contrato.
///
/// Fail-open al crudo: ante un valor que el cliente no conoce (drift de
/// contrato), mostrar la jerga es igual de seguro que hoy y no oculta datos.
library;

String roleLabel(String role) => switch (role) {
  'OWNER' => 'Propietario',
  'ADMIN' => 'Administrador',
  'SUPERVISOR' => 'Supervisor',
  'WORKER' => 'Agente',
  _ => role,
};

String invitationStatusLabel(String status) => switch (status) {
  'PENDING' => 'Pendiente',
  'ACCEPTED' => 'Aceptada',
  'CANCELED' => 'Cancelada',
  _ => status,
};
