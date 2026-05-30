import '../../domain/entities/chat_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_datasource.dart';

/// Implementación trivial: delega en el datasource (refresco contra el backend
/// en cada consulta, sin cache local en esta capa). La orquestación de verdad
/// local vs. remota la cubre RFC-0001.
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({required ProfileDatasource datasource})
    : _ds = datasource;

  final ProfileDatasource _ds;

  @override
  Future<ChatProfile> fetch(String botId, String chatLid) =>
      _ds.fetch(botId, chatLid);
}
