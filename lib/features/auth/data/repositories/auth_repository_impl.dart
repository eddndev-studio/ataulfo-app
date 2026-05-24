import '../../domain/entities/auth_tokens.dart';
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
  }) : _ds = datasource,
       _storage = storage;

  final AuthDatasource _ds;
  final TokenStorage _storage;

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final tokens = await _ds.login(email: email, password: password);
    await _storage.save(tokens);
    return tokens;
  }
}
