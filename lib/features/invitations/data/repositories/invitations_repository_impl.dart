import '../../domain/entities/invitation.dart';
import '../../domain/repositories/invitations_repository.dart';
import '../datasources/invitations_datasource.dart';

/// Implementación trivial del puerto: delega en el datasource.
class InvitationsRepositoryImpl implements InvitationsRepository {
  InvitationsRepositoryImpl({required InvitationsDatasource datasource})
    : _ds = datasource;

  final InvitationsDatasource _ds;

  @override
  Future<List<Invitation>> list() => _ds.list();

  @override
  Future<void> create(String email, String role) => _ds.create(email, role);

  @override
  Future<void> cancel(String id) => _ds.cancel(id);
}
