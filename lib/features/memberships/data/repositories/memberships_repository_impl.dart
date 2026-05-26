import '../../domain/entities/membership.dart';
import '../../domain/repositories/memberships_repository.dart';
import '../datasources/memberships_datasource.dart';

/// Implementación trivial del puerto: el listado refresca contra el backend
/// en cada open. Cuando aterrice RFC-0001 (cache + sync), esta clase
/// orquestará la verdad local vs. remota; hoy es delegate.
class MembershipsRepositoryImpl implements MembershipsRepository {
  MembershipsRepositoryImpl({required MembershipsDatasource datasource})
    : _ds = datasource;

  final MembershipsDatasource _ds;

  @override
  Future<List<Membership>> list() => _ds.list();
}
