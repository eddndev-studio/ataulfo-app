import '../entities/member.dart';

/// Puerto del repositorio del feature members. La capa de presentación depende
/// de esta interface, no del datasource: cuando aterrice cache local
/// (RFC-0001), la implementación orquesta verdad local vs. remota sin reabrir
/// el contrato.
abstract interface class MembersRepository {
  /// Lista los miembros de la organización activa. Array vacío legítimo
  /// (200 con []).
  Future<List<Member>> list();
}
