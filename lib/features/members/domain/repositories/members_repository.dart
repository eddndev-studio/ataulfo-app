import '../entities/member.dart';

/// Puerto del repositorio del feature members. La capa de presentación depende
/// de esta interface, no del datasource: cuando aterrice cache local
/// (RFC-0001), la implementación orquesta verdad local vs. remota sin reabrir
/// el contrato.
abstract interface class MembersRepository {
  /// Lista los miembros de la organización activa. Array vacío legítimo
  /// (200 con []).
  Future<List<Member>> list();

  /// Cambia el rol del miembro [membershipId] al [role] (uppercase del set
  /// cerrado del backend). Completa sin valor en 204; lanza `MembersFailure`
  /// tipada ante el rechazo del servidor (self-upgrade, sole-owner, etc.).
  Future<void> changeRole(String membershipId, String role);

  /// Quita al miembro [membershipId] de la organización activa. Completa sin
  /// valor en 204; lanza `MembersFailure` tipada (sole-owner, not-found, etc.).
  Future<void> removeMember(String membershipId);

  /// Transfiere la propiedad de la org al miembro [membershipId] (swap: el
  /// caller pasa a ADMIN, el destino a OWNER). Sólo un OWNER real puede; el
  /// backend 403ea aun a un admin. Completa en 204.
  Future<void> transferOwnership(String membershipId);

  /// Ids de los bots asignados al miembro [membershipId]. Sólo relevante para
  /// WORKER (SUPERVISOR+ ve todos). Lista vacía legítima.
  Future<List<String>> assignedBots(String membershipId);

  /// Reemplaza el set COMPLETO de bots asignados al miembro [membershipId] con
  /// [botIds] (no es aditivo; `[]` desasigna todo). Completa en 204.
  Future<void> assignBots(String membershipId, List<String> botIds);
}
