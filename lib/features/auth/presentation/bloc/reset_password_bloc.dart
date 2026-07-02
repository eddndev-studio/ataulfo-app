import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// Mínimo de longitud de contraseña que exige el backend en
/// `/auth/reset-password`. El cliente lo valida antes de pegar al servidor para
/// dar feedback inmediato; el backend sigue siendo la autoridad (un
/// `WeakPasswordFailure` 400 también se mapea a `passwordTooShort`).
const int _minPasswordLength = 12;

/// Número de dígitos del código de reset (OTP). El código llega por correo; el
/// cliente valida la forma exacta antes de canjear para no gastar un viaje ni
/// consumir un intento del lockout con un código a medio escribir.
const int _codeLength = 6;

final RegExp _codeShape = RegExp('^\\d{$_codeLength}\$');

/// Bloc del restablecimiento de contraseña. Toma el correo, el código de 6
/// dígitos que llegó por correo y la nueva contraseña, y canjea contra el
/// backend.
///
/// El canje es destructivo y de un solo uso: en 204 el backend revoca todas las
/// familias de refresh del usuario, así que la página debe llevar la sesión
/// local a "sin sesión" y rutear al login. La validación de cliente (correo con
/// forma mínima, código de 6 dígitos, longitud de contraseña) ocurre ANTES de
/// llamar al repositorio: un envío inválido no gasta el código ni suma al
/// lockout. Los fallos del backend re-renderizan el form para reintentar.
class ResetPasswordBloc extends Bloc<ResetPasswordEvent, ResetPasswordState> {
  ResetPasswordBloc(this._repo) : super(const ResetPasswordInitial()) {
    on<ResetPasswordSubmitted>(_onSubmitted);
  }

  final AuthRepository _repo;

  Future<void> _onSubmitted(
    ResetPasswordSubmitted event,
    Emitter<ResetPasswordState> emit,
  ) async {
    final email = event.email.trim();
    // Forma mínima del correo: no vacío y con arroba. El formato fino lo juzga
    // el backend (el 404 anti-enumeración no distingue correo de código).
    if (email.isEmpty || !email.contains('@')) {
      emit(const ResetPasswordFailed(ResetPasswordFailureKind.invalidInput));
      return;
    }
    if (!_codeShape.hasMatch(event.code)) {
      emit(const ResetPasswordFailed(ResetPasswordFailureKind.invalidCode));
      return;
    }
    if (event.newPassword.length < _minPasswordLength) {
      emit(
        const ResetPasswordFailed(ResetPasswordFailureKind.passwordTooShort),
      );
      return;
    }
    emit(const ResetPasswordSubmitting());
    try {
      await _repo.resetPassword(
        email: email,
        code: event.code,
        newPassword: event.newPassword,
      );
      emit(const ResetPasswordSucceeded());
    } on AuthFailure catch (e) {
      emit(ResetPasswordFailed(_kindOf(e)));
    }
  }

  ResetPasswordFailureKind _kindOf(AuthFailure e) => switch (e) {
    WeakPasswordFailure() => ResetPasswordFailureKind.passwordTooShort,
    InvalidTokenFailure() => ResetPasswordFailureKind.invalidCode,
    ExpiredTokenFailure() => ResetPasswordFailureKind.expiredCode,
    NetworkFailure() => ResetPasswordFailureKind.network,
    // Las variantes de otros endpoints del arco de auth no pueden surgir
    // contra `/auth/reset-password`; se colapsan a genérico.
    InvalidCredentialsFailure() ||
    RateLimitedFailure() ||
    EmailTakenFailure() ||
    EmailMismatchFailure() ||
    AlreadyMemberFailure() ||
    NotMemberFailure() ||
    EmailNotVerifiedFailure() ||
    UnknownAuthFailure() => ResetPasswordFailureKind.unknown,
  };
}

// Events --------------------------------------------------------------------

sealed class ResetPasswordEvent {
  const ResetPasswordEvent();
}

class ResetPasswordSubmitted extends ResetPasswordEvent {
  const ResetPasswordSubmitted({
    required this.email,
    required this.code,
    required this.newPassword,
  });

  final String email;
  final String code;
  final String newPassword;

  @override
  bool operator ==(Object other) =>
      other is ResetPasswordSubmitted &&
      other.email == email &&
      other.code == code &&
      other.newPassword == newPassword;

  @override
  int get hashCode => Object.hash(email, code, newPassword);
}

// States --------------------------------------------------------------------

sealed class ResetPasswordState {
  const ResetPasswordState();
}

class ResetPasswordInitial extends ResetPasswordState {
  const ResetPasswordInitial();

  @override
  bool operator ==(Object other) => other is ResetPasswordInitial;

  @override
  int get hashCode => (ResetPasswordInitial).hashCode;
}

class ResetPasswordSubmitting extends ResetPasswordState {
  const ResetPasswordSubmitting();

  @override
  bool operator ==(Object other) => other is ResetPasswordSubmitting;

  @override
  int get hashCode => (ResetPasswordSubmitting).hashCode;
}

/// Contraseña restablecida. El backend ya revocó todas las familias de
/// refresh; la UI lleva la sesión local a "sin sesión" y rutea al login.
class ResetPasswordSucceeded extends ResetPasswordState {
  const ResetPasswordSucceeded();

  @override
  bool operator ==(Object other) => other is ResetPasswordSucceeded;

  @override
  int get hashCode => (ResetPasswordSucceeded).hashCode;
}

class ResetPasswordFailed extends ResetPasswordState {
  const ResetPasswordFailed(this.kind);

  final ResetPasswordFailureKind kind;

  @override
  bool operator ==(Object other) =>
      other is ResetPasswordFailed && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

enum ResetPasswordFailureKind {
  invalidInput,
  passwordTooShort,
  invalidCode,
  expiredCode,
  network,
  unknown,
}
