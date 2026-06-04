/// DTO del wire de `GET /workspace/members`.
///
/// Espeja `memberResp` del backend: claves snake_case del wire viven aquí; el
/// dominio expone `camelCase` vía mapper. `role` viaja crudo (set cerrado del
/// backend: OWNER/ADMIN/SUPERVISOR/WORKER). El wire trae también `org_id`, pero
/// es redundante (todos los miembros comparten la org activa) y no se parsea.
class MemberResp {
  const MemberResp({
    required this.id,
    required this.userId,
    required this.email,
    required this.emailVerified,
    required this.role,
  });

  factory MemberResp.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final userId = json['user_id'];
    final email = json['email'];
    final emailVerified = json['email_verified'];
    final role = json['role'];
    if (id is! String ||
        userId is! String ||
        email is! String ||
        emailVerified is! bool ||
        role is! String) {
      throw const FormatException('memberResp: clave obligatoria ausente');
    }
    return MemberResp(
      id: id,
      userId: userId,
      email: email,
      emailVerified: emailVerified,
      role: role,
    );
  }

  final String id;
  final String userId;
  final String email;
  final bool emailVerified;
  final String role;
}
