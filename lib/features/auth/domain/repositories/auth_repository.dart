import '../entities/accepted_invitation.dart';
import '../entities/auth_tokens.dart';
import '../entities/identity.dart';
import '../entities/pending_invitation.dart';

/// Puerto de autenticación expuesto al bloc/UI.
///
/// Los métodos lanzan `AuthFailure` (jerarquía sellada en
/// `domain/failures/auth_failure.dart`); el bloc atrapa y traduce a estados.
abstract interface class AuthRepository {
  Future<AuthTokens> login({required String email, required String password});

  /// Alta de cuenta. Como el login, persiste el par de tokens devuelto antes
  /// de retornar — el alta deja sesión iniciada (la cuenta nace con su org
  /// personal OWNER).
  Future<AuthTokens> register({
    required String email,
    required String password,
  });

  /// Canjea el código de verificación de email. No persiste tokens; devuelve
  /// `true` si la cuenta YA estaba verificada (re-canje idempotente) para que
  /// la UI no muestre un éxito recién hecho, `false` si la verificó ahora.
  Future<bool> verifyEmail({required String email, required String code});

  /// Solicita el correo de reset de contraseña. Público (sin sesión).
  Future<void> forgotPassword(String email);

  /// Canjea el código de reset y fija la nueva contraseña. Público (sin
  /// sesión); no inicia sesión por sí mismo.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  /// Cambia la org activa de la sesión. Persiste el nuevo par de tokens (los
  /// claims llevan la org elegida) igual que el login.
  Future<AuthTokens> switchOrg(String orgId);

  /// Crea una organización nueva con [name] y deja al caller OWNER. Como el
  /// switch-org, el backend re-emite un par con la org nueva ya activa, así que
  /// persiste el par devuelto: tras esto la sesión "vive" en la org nueva (el
  /// llamador releerá `/auth/me` para reflejarlo).
  Future<AuthTokens> createOrganization(String name);

  /// Renombra la organización activa. No toca tokens (el id de la org no
  /// cambia; el nombre no viaja en el JWT). El nombre fresco se observa
  /// re-listando memberships.
  Future<void> renameOrganization(String name);

  /// Acepta una invitación pendiente. No persiste tokens — la membership
  /// nueva requiere un switch-org explícito posterior.
  Future<void> acceptInvitation(String token);

  /// Reenvía el correo de verificación al email de la sesión actual.
  Future<void> resendVerification();

  /// Lista las invitaciones pendientes dirigidas al correo de la sesión. El
  /// backend devuelve `[]` si el correo no está verificado; la lista vacía no
  /// es un fallo.
  Future<List<PendingInvitation>> pendingInvitations();

  /// Acepta una invitación pendiente por su id. No persiste tokens — la
  /// membership nueva requiere un switch-org explícito posterior. Devuelve la
  /// membership recién creada (nombre para confirmar el ingreso).
  Future<AcceptedInvitation> acceptPendingInvitation(String invitationId);

  /// Resuelve la identidad del portador del access token (S02 `/auth/me`).
  /// No persiste — el dato es barato de re-pedir y agregar otra cache aquí
  /// sería estado sombra del JWT.
  Future<Identity> me();

  /// Fast-path para el arranque: indica si hay tokens persistidos sin
  /// validarlos contra el backend. El bloc lo usa para evitar un golpe
  /// inútil a `/auth/me` cuando no hay sesión que verificar.
  Future<bool> hasTokens();

  /// Logout: revoca la familia contra el backend (best-effort) y purga
  /// los tokens locales. Idempotente — si no hay tokens persistidos,
  /// no-op. El cliente queda en estado sin sesión incluso si la
  /// revocación remota falla por red.
  Future<void> logout();
}
