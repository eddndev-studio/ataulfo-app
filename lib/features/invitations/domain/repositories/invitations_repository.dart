import '../entities/invitation.dart';

/// Puerto del repositorio del feature invitations. La presentación depende de
/// esta interface, no del datasource.
abstract interface class InvitationsRepository {
  /// Historial completo de invitaciones de la org activa (PENDING + terminales).
  /// Array vacío legítimo (200 con []).
  Future<List<Invitation>> list();

  /// Emite una invitación al [email] con el [role] (uppercase del set cerrado).
  /// El token viaja sólo por correo; nunca vuelve en la respuesta. Completa sin
  /// valor en 201; lanza `InvitationsFailure` tipada ante el rechazo.
  Future<void> create(String email, String role);

  /// Cancela (soft) la invitación [id]. Completa sin valor en 204; lanza
  /// `InvitationsFailure` tipada (not-found, gone, etc.).
  Future<void> cancel(String id);
}
