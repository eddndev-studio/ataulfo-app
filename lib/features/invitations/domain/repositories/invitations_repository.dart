import '../entities/created_invitation.dart';
import '../entities/invitation.dart';

/// Puerto del repositorio del feature invitations. La presentación depende de
/// esta interface, no del datasource.
abstract interface class InvitationsRepository {
  /// Historial completo de invitaciones de la org activa (PENDING + terminales).
  /// Array vacío legítimo (200 con []).
  Future<List<Invitation>> list();

  /// Emite una invitación al [email] con el [role] (uppercase del set cerrado).
  /// Devuelve el [CreatedInvitation] con el token crudo a compartir y si el
  /// correo salió; lanza `InvitationsFailure` tipada ante el rechazo.
  Future<CreatedInvitation> create(
    String email,
    String role,
    List<String> botIds,
  );

  /// Cancela (soft) la invitación [id]. Completa sin valor en 204; lanza
  /// `InvitationsFailure` tipada (not-found, gone, etc.).
  Future<void> cancel(String id);
}
