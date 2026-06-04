import '../../domain/entities/auth_tokens.dart';
import '../../domain/entities/identity.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';
import 'token_storage.dart';

/// Implementación del puerto: orquesta datasource + persistencia segura.
///
/// La capa data es delgada — su responsabilidad es asegurar que el efecto
/// secundario (storage) sólo ocurre si la llamada al backend tuvo éxito.
/// Un fallo del datasource se propaga sin tocar el storage.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthDatasource datasource,
    required TokenStorage storage,
    Future<void> Function()? onBeforeLogout,
  }) : _ds = datasource,
       _storage = storage,
       _onBeforeLogout = onBeforeLogout;

  final AuthDatasource _ds;
  final TokenStorage _storage;

  /// Gancho que corre durante el logout MIENTRAS los tokens siguen
  /// persistidos — antes de revocar la familia y de purgar el storage. Lo usa
  /// la composición para limpiar estado dependiente de la sesión que requiere
  /// un Bearer vivo (p. ej. desregistrar el device de push); de otro modo el
  /// request viajaría sin Authorization tras el clear y el efecto fallaría
  /// silenciosamente, dejando el device atado al usuario saliente. Best-effort:
  /// un fallo del gancho no aborta el teardown de sesión.
  final Future<void> Function()? _onBeforeLogout;

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final tokens = await _ds.login(email: email, password: password);
    await _storage.save(tokens);
    return tokens;
  }

  @override
  Future<AuthTokens> register({
    required String email,
    required String password,
  }) async {
    final tokens = await _ds.register(email: email, password: password);
    await _storage.save(tokens);
    return tokens;
  }

  @override
  Future<bool> verifyEmail(String token) async =>
      (await _ds.verifyEmail(token)).alreadyVerified;

  @override
  Future<void> forgotPassword(String email) => _ds.forgotPassword(email);

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) => _ds.resetPassword(token: token, newPassword: newPassword);

  @override
  Future<AuthTokens> switchOrg(String orgId) async {
    final tokens = await _ds.switchOrg(orgId);
    await _storage.save(tokens);
    return tokens;
  }

  @override
  Future<AuthTokens> createOrganization(String name) async {
    final tokens = await _ds.createOrganization(name);
    await _storage.save(tokens);
    return tokens;
  }

  @override
  Future<void> renameOrganization(String name) => _ds.renameOrganization(name);

  @override
  Future<void> acceptInvitation(String token) => _ds.acceptInvitation(token);

  @override
  Future<void> resendVerification() => _ds.resendVerification();

  @override
  Future<Identity> me() async => _ds.me();

  @override
  Future<bool> hasTokens() async => (await _storage.read()) != null;

  @override
  Future<void> logout() async {
    final tokens = await _storage.read();
    if (tokens == null) return;
    final hook = _onBeforeLogout;
    if (hook != null) {
      try {
        await hook();
      } catch (_) {
        // Best-effort: el gancho de pre-logout no debe impedir que la sesión
        // local quede revocada y purgada. Cualquier fallo se traga aquí.
      }
    }
    try {
      await _ds.logout(tokens.refreshToken);
    } on AuthFailure {
      // Revocación remota best-effort: el contrato del logout es que el
      // cliente quede en estado sin sesión incluso si el backend está
      // caído o el bearer ya está revocado. El interceptor purgaría
      // storage en su propio path; aquí asumimos la responsabilidad
      // explícitamente.
    }
    await _storage.clear();
  }
}
