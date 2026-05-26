import '../entities/membership.dart';

/// Puerto del repositorio del feature memberships. La capa de presentación
/// depende de esta interface, no del datasource: cuando aterrice cache local
/// (RFC-0001), la implementación orquesta verdad local vs. remota sin
/// reabrir el contrato.
abstract interface class MembershipsRepository {
  /// Lista las orgs del operador. Array vacío legítimo (200 con []).
  Future<List<Membership>> list();
}
