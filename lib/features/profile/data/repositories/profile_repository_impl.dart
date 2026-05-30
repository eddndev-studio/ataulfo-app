import '../../domain/entities/chat_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_datasource.dart';

/// Implementación trivial: delega en el datasource (refresco contra el backend
/// en cada open, sin cache local en esta capa). Cuando aterrice RFC-0001 esta
/// clase orquestará verdad local vs. remota.
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({required ProfileDatasource datasource})
    : _ds = datasource;

  final ProfileDatasource _ds;

  @override
  Future<ChatProfile> fetch(String botId, String chatLid) =>
      _ds.fetch(botId, chatLid);
}
