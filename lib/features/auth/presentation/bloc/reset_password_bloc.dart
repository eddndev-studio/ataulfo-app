import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../util/reset_link.dart';

/// Mínimo de longitud de contraseña que exige el backend en
/// `/auth/reset-password`. El cliente lo valida antes de pegar al servidor para
/// dar feedback inmediato; el backend sigue siendo la autoridad (un
/// `WeakPasswordFailure` 400 también se mapea a `passwordTooShort`).
const int _minPasswordLength = 12;

/// Bloc del restablecimiento de contraseña. Toma lo que el operador pegó (el
/// enlace del correo o el token suelto) más la nueva contraseña, extrae el
/// token y canjea contra el backend.
///
/// El canje es destructivo y de un solo uso: en 204 el backend revoca todas
/// las familias de refresh del usuario, así que la página debe llevar la
/// sesión local a "sin sesión" y rutear al login. La validación de cliente
/// (token presente, longitud) ocurre ANTES de llamar al repositorio: un envío
/// inválido no gasta el token. Los fallos del backend re-renderizan el form con
/// el mismo enlace para reintentar (el token NO se consume en un fallo).
class ResetPasswordBloc extends Bloc<ResetPasswordEvent, ResetPasswordState> {
  ResetPasswordBloc(this._repo) : super(const ResetPasswordInitial()) {
    on<ResetPasswordSubmitted>(_onSubmitted);
  }

  final AuthRepository _repo;

  Future<void> _onSubmitted(
    ResetPasswordSubmitted event,
    Emitter<ResetPasswordState> emit,
  ) async {
    final token = extractResetToken(event.pastedLinkOrToken);
    if (token.isEmpty) {
      emit(const ResetPasswordFailed(ResetPasswordFailureKind.invalidInput));
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
      await _repo.resetPassword(token: token, newPassword: event.newPassword);
      emit(const ResetPasswordSucceeded());
    } on AuthFailure catch (e) {
      emit(ResetPasswordFailed(_kindOf(e)));
    }
  }

  ResetPasswordFailureKind _kindOf(AuthFailure e) => switch (e) {
    WeakPasswordFailure() => ResetPasswordFailureKind.passwordTooShort,
    InvalidTokenFailure() => ResetPasswordFailureKind.invalidLink,
    ExpiredTokenFailure() => ResetPasswordFailureKind.expiredLink,
    NetworkFailure() => ResetPasswordFailureKind.network,
    // Las variantes de otros endpoints del arco de auth no pueden surgir
    // contra `/auth/reset-password`; se colapsan a genérico.
    InvalidCredentialsFailure() ||
    RateLimitedFailure() ||
    EmailTakenFailure() ||
    EmailMismatchFailure() ||
    AlreadyMemberFailure() ||
    NotMemberFailure() ||
    UnknownAuthFailure() => ResetPasswordFailureKind.unknown,
  };
}

// Events --------------------------------------------------------------------

sealed class ResetPasswordEvent {
  const ResetPasswordEvent();
}

class ResetPasswordSubmitted extends ResetPasswordEvent {
  const ResetPasswordSubmitted({
    required this.pastedLinkOrToken,
    required this.newPassword,
  });

  /// Lo que el operador pegó: el enlace del correo o el token crudo. El bloc
  /// lo normaliza con `extractResetToken` antes de canjear.
  final String pastedLinkOrToken;
  final String newPassword;

  @override
  bool operator ==(Object other) =>
      other is ResetPasswordSubmitted &&
      other.pastedLinkOrToken == pastedLinkOrToken &&
      other.newPassword == newPassword;

  @override
  int get hashCode => Object.hash(pastedLinkOrToken, newPassword);
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
  invalidLink,
  expiredLink,
  network,
  unknown,
}
