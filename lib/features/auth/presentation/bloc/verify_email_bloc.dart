import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../util/pasted_token.dart';

/// Bloc de la verificación de correo. Toma lo que el operador pegó (el enlace
/// del correo o el token suelto), extrae el token y lo canjea contra el backend.
///
/// El correo de verificación abre el SERVIDOR, no la app; no hay deep-link que
/// rellene el campo, así que el operador pega texto a mano. La validación de
/// cliente (token presente) ocurre ANTES de llamar al repositorio: un envío en
/// blanco no gasta un viaje al backend. El canje es idempotente: si la cuenta ya
/// estaba verificada el repositorio devuelve `true`, y la UI ramifica el copy
/// (sin un "éxito" recién hecho); `false` significa que se verificó ahora.
class VerifyEmailBloc extends Bloc<VerifyEmailEvent, VerifyEmailState> {
  VerifyEmailBloc(this._repo) : super(const VerifyEmailInitial()) {
    on<VerifyEmailSubmitted>(_onSubmitted);
  }

  final AuthRepository _repo;

  Future<void> _onSubmitted(
    VerifyEmailSubmitted event,
    Emitter<VerifyEmailState> emit,
  ) async {
    final token = extractPastedToken(event.pastedLinkOrToken);
    if (token.isEmpty) {
      emit(const VerifyEmailFailed(VerifyEmailFailureKind.invalidInput));
      return;
    }
    emit(const VerifyEmailSubmitting());
    try {
      final alreadyVerified = await _repo.verifyEmail(token);
      emit(VerifyEmailSucceeded(alreadyVerified: alreadyVerified));
    } on AuthFailure catch (e) {
      emit(VerifyEmailFailed(_kindOf(e)));
    }
  }

  VerifyEmailFailureKind _kindOf(AuthFailure e) => switch (e) {
    InvalidTokenFailure() => VerifyEmailFailureKind.invalidLink,
    ExpiredTokenFailure() => VerifyEmailFailureKind.expiredLink,
    NetworkFailure() => VerifyEmailFailureKind.network,
    // Las variantes de otros endpoints del arco de auth no pueden surgir
    // contra `/auth/verify-email`; se colapsan a genérico.
    InvalidCredentialsFailure() ||
    RateLimitedFailure() ||
    EmailTakenFailure() ||
    WeakPasswordFailure() ||
    EmailMismatchFailure() ||
    AlreadyMemberFailure() ||
    NotMemberFailure() ||
    UnknownAuthFailure() => VerifyEmailFailureKind.unknown,
  };
}

// Events --------------------------------------------------------------------

sealed class VerifyEmailEvent {
  const VerifyEmailEvent();
}

class VerifyEmailSubmitted extends VerifyEmailEvent {
  const VerifyEmailSubmitted(this.pastedLinkOrToken);

  /// Lo que el operador pegó: el enlace del correo o el token crudo. El bloc
  /// lo normaliza con `extractPastedToken` antes de canjear.
  final String pastedLinkOrToken;

  @override
  bool operator ==(Object other) =>
      other is VerifyEmailSubmitted &&
      other.pastedLinkOrToken == pastedLinkOrToken;

  @override
  int get hashCode => pastedLinkOrToken.hashCode;
}

// States --------------------------------------------------------------------

sealed class VerifyEmailState {
  const VerifyEmailState();
}

class VerifyEmailInitial extends VerifyEmailState {
  const VerifyEmailInitial();

  @override
  bool operator ==(Object other) => other is VerifyEmailInitial;

  @override
  int get hashCode => (VerifyEmailInitial).hashCode;
}

class VerifyEmailSubmitting extends VerifyEmailState {
  const VerifyEmailSubmitting();

  @override
  bool operator ==(Object other) => other is VerifyEmailSubmitting;

  @override
  int get hashCode => (VerifyEmailSubmitting).hashCode;
}

/// Correo verificado. `alreadyVerified` distingue el re-click idempotente (la
/// cuenta YA estaba verificada) de la verificación recién hecha, para que la UI
/// ramifique el copy (sin un aviso de éxito nuevo cuando ya estaba verificada).
class VerifyEmailSucceeded extends VerifyEmailState {
  const VerifyEmailSucceeded({required this.alreadyVerified});

  final bool alreadyVerified;

  @override
  bool operator ==(Object other) =>
      other is VerifyEmailSucceeded && other.alreadyVerified == alreadyVerified;

  @override
  int get hashCode => alreadyVerified.hashCode;
}

class VerifyEmailFailed extends VerifyEmailState {
  const VerifyEmailFailed(this.kind);

  final VerifyEmailFailureKind kind;

  @override
  bool operator ==(Object other) =>
      other is VerifyEmailFailed && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

enum VerifyEmailFailureKind {
  invalidInput,
  invalidLink,
  expiredLink,
  network,
  unknown,
}
