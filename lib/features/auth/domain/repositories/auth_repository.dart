import '../entities/auth_tokens.dart';

/// Puerto de autenticación expuesto al bloc/UI.
///
/// Los métodos lanzan `AuthFailure` (jerarquía sellada en
/// `domain/failures/auth_failure.dart`); el bloc atrapa y traduce a estados.
abstract interface class AuthRepository {
  Future<AuthTokens> login({required String email, required String password});
}
