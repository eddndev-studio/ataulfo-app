import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// Número de dígitos del código de verificación (OTP).
const int _codeLength = 6;

final RegExp _codeShape = RegExp('^\\d{$_codeLength}\$');

/// Bloc de la verificación de correo. Toma el correo y el código de 6 dígitos
/// que llegó por correo y lo canjea contra el backend.
///
/// El correo entrega un código, no un enlace: el operador lo escribe. La
/// validación de cliente (correo con forma mínima, código de 6 dígitos) ocurre
/// ANTES de llamar al repositorio: un envío inválido no gasta un viaje al
/// backend. El canje es idempotente: si la cuenta ya estaba verificada el
/// repositorio devuelve `true`, y la UI ramifica el copy (sin un "éxito" recién
/// hecho); `false` significa que se verificó ahora.
class VerifyEmailBloc extends Bloc<VerifyEmailEvent, VerifyEmailState> {
  VerifyEmailBloc(this._repo) : super(const VerifyEmailInitial()) {
    on<VerifyEmailSubmitted>(_onSubmitted);
  }

  final AuthRepository _repo;

  Future<void> _onSubmitted(
    VerifyEmailSubmitted event,
    Emitter<VerifyEmailState> emit,
  ) async {
    final email = event.email.trim();
    if (email.isEmpty || !email.contains('@')) {
      emit(const VerifyEmailFailed(VerifyEmailFailureKind.invalidInput));
      return;
    }
    if (!_codeShape.hasMatch(event.code)) {
      emit(const VerifyEmailFailed(VerifyEmailFailureKind.invalidCode));
      return;
    }
    emit(const VerifyEmailSubmitting());
    try {
      final alreadyVerified = await _repo.verifyEmail(
        email: email,
        code: event.code,
      );
      emit(VerifyEmailSucceeded(alreadyVerified: alreadyVerified));
    } on AuthFailure catch (e) {
      emit(VerifyEmailFailed(_kindOf(e)));
    }
  }

  VerifyEmailFailureKind _kindOf(AuthFailure e) => switch (e) {
    InvalidTokenFailure() => VerifyEmailFailureKind.invalidCode,
    ExpiredTokenFailure() => VerifyEmailFailureKind.expiredCode,
    NetworkFailure() => VerifyEmailFailureKind.network,
    // 429 por el límite de tasa por-IP del canje: distinto del lockout de
    // intentos (que ya cae en invalidCode/expiredCode vía el backend), así
    // que se distingue con su propio copy ("espera un momento").
    RateLimitedFailure() => VerifyEmailFailureKind.rateLimited,
    // Las variantes de otros endpoints del arco de auth no pueden surgir
    // contra `/auth/verify-email`; se colapsan a genérico.
    InvalidCredentialsFailure() ||
    EmailTakenFailure() ||
    WeakPasswordFailure() ||
    EmailMismatchFailure() ||
    AlreadyMemberFailure() ||
    NotMemberFailure() ||
    EmailNotVerifiedFailure() ||
    UnknownAuthFailure() => VerifyEmailFailureKind.unknown,
  };
}

// Events --------------------------------------------------------------------

sealed class VerifyEmailEvent {
  const VerifyEmailEvent();
}

class VerifyEmailSubmitted extends VerifyEmailEvent {
  const VerifyEmailSubmitted({required this.email, required this.code});

  final String email;
  final String code;

  @override
  bool operator ==(Object other) =>
      other is VerifyEmailSubmitted &&
      other.email == email &&
      other.code == code;

  @override
  int get hashCode => Object.hash(email, code);
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
  invalidCode,
  expiredCode,
  network,
  rateLimited,
  unknown,
}
