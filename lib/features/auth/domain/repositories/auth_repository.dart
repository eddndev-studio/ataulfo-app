import '../entities/auth_tokens.dart';
import '../entities/identity.dart';

/// Puerto de autenticación expuesto al bloc/UI.
///
/// Los métodos lanzan `AuthFailure` (jerarquía sellada en
/// `domain/failures/auth_failure.dart`); el bloc atrapa y traduce a estados.
abstract interface class AuthRepository {
  Future<AuthTokens> login({required String email, required String password});

  /// Resuelve la identidad del portador del access token (S02 `/auth/me`).
  /// No persiste — el dato es barato de re-pedir y agregar otra cache aquí
  /// sería estado sombra del JWT.
  Future<Identity> me();
}
