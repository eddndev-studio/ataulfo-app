import 'dart:convert';

import '../../../../core/storage/secure_kv_store.dart';
import '../../domain/entities/auth_tokens.dart';

/// Persistencia cifrada del par AuthTokens.
///
/// Serializa a JSON sobre el `SecureKvStore`. Un payload corrupto se trata
/// como ausencia (devuelve null) — la causa más probable es un upgrade que
/// dejó un blob de versión anterior; el cliente fuerza re-login en ese caso
/// sin reportar error.
class TokenStorage {
  TokenStorage(this._kv);

  static const String _key = 'auth.tokens.v1';

  final SecureKvStore _kv;

  Future<void> save(AuthTokens tokens) async {
    final payload = jsonEncode(<String, dynamic>{
      'access': tokens.accessToken,
      'refresh': tokens.refreshToken,
      'type': tokens.tokenType,
      'expiresIn': tokens.expiresInSeconds,
    });
    await _kv.write(_key, payload);
  }

  Future<AuthTokens?> read() async {
    final raw = await _kv.read(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final access = json['access'];
      final refresh = json['refresh'];
      final type = json['type'];
      final expiresIn = json['expiresIn'];
      if (access is! String ||
          refresh is! String ||
          type is! String ||
          expiresIn is! int) {
        return null;
      }
      return AuthTokens(
        accessToken: access,
        refreshToken: refresh,
        tokenType: type,
        expiresInSeconds: expiresIn,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> clear() => _kv.delete(_key);
}
