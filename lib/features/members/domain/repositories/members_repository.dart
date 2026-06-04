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
}
