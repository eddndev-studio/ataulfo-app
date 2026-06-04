import '../../domain/entities/member.dart';
import '../../domain/repositories/members_repository.dart';
import '../datasources/members_datasource.dart';

/// Implementación trivial del puerto: el listado refresca contra el backend en
/// cada open. Cuando aterrice RFC-0001 (cache + sync), esta clase orquestará la
/// verdad local vs. remota; hoy es delegate.
class MembersRepositoryImpl implements MembersRepository {
  MembersRepositoryImpl({required MembersDatasource datasource})
    : _ds = datasource;

  final MembersDatasource _ds;

  @override
  Future<List<Member>> list() => _ds.list();
}
