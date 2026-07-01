import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// Bloc de "olvidé mi contraseña". Pide al backend que envíe el correo de
/// reset y expone estados que la UI consume directo.
///
/// El backend devuelve 202 SIEMPRE, exista o no la cuenta (anti enumeración):
/// no se puede saber desde el cliente si el correo se mandó de verdad. Por eso
/// el éxito SIEMPRE es `Sent` y la página muestra un copy genérico ("si existe
/// una cuenta…") que nunca confirma la existencia. Sólo los fallos de
/// transporte (red, rate limit, error genérico) se exponen como error; ninguno
/// de ellos filtra si la cuenta existe.
class ForgotPasswordBloc
    extends Bloc<ForgotPasswordEvent, ForgotPasswordState> {
  ForgotPasswordBloc(this._repo) : super(const ForgotPasswordInitial()) {
    on<ForgotPasswordSubmitted>(_onSubmitted);
  }

  final AuthRepository _repo;

  Future<void> _onSubmitted(
    ForgotPasswordSubmitted event,
    Emitter<ForgotPasswordState> emit,
  ) async {
    emit(const ForgotPasswordSubmitting());
    try {
      await _repo.forgotPassword(event.email);
      emit(const ForgotPasswordSent());
    } on AuthFailure catch (e) {
      emit(ForgotPasswordFailed(_kindOf(e)));
    }
  }

  ForgotPasswordFailureKind _kindOf(AuthFailure e) => switch (e) {
    NetworkFailure() => ForgotPasswordFailureKind.network,
    RateLimitedFailure() => ForgotPasswordFailureKind.rateLimited,
    // El endpoint es anti-enumeración: ningún failure puede revelar si la
    // cuenta existe. Todo lo demás se colapsa a genérico — nunca se mapea a
    // un estado que implique "esa cuenta sí/no existe".
    InvalidCredentialsFailure() ||
    EmailTakenFailure() ||
    WeakPasswordFailure() ||
    InvalidTokenFailure() ||
    ExpiredTokenFailure() ||
    EmailMismatchFailure() ||
    AlreadyMemberFailure() ||
    NotMemberFailure() ||
    EmailNotVerifiedFailure() ||
    UnknownAuthFailure() => ForgotPasswordFailureKind.unknown,
  };
}

// Events --------------------------------------------------------------------

sealed class ForgotPasswordEvent {
  const ForgotPasswordEvent();
}

class ForgotPasswordSubmitted extends ForgotPasswordEvent {
  const ForgotPasswordSubmitted({required this.email});

  final String email;

  @override
  bool operator ==(Object other) =>
      other is ForgotPasswordSubmitted && other.email == email;

  @override
  int get hashCode => email.hashCode;
}

// States --------------------------------------------------------------------

sealed class ForgotPasswordState {
  const ForgotPasswordState();
}

class ForgotPasswordInitial extends ForgotPasswordState {
  const ForgotPasswordInitial();

  @override
  bool operator ==(Object other) => other is ForgotPasswordInitial;

  @override
  int get hashCode => (ForgotPasswordInitial).hashCode;
}

class ForgotPasswordSubmitting extends ForgotPasswordState {
  const ForgotPasswordSubmitting();

  @override
  bool operator ==(Object other) => other is ForgotPasswordSubmitting;

  @override
  int get hashCode => (ForgotPasswordSubmitting).hashCode;
}

/// Solicitud aceptada por el backend. NO implica que la cuenta exista — el
/// 202 es incondicional. La UI muestra copy genérico desde este estado.
class ForgotPasswordSent extends ForgotPasswordState {
  const ForgotPasswordSent();

  @override
  bool operator ==(Object other) => other is ForgotPasswordSent;

  @override
  int get hashCode => (ForgotPasswordSent).hashCode;
}

class ForgotPasswordFailed extends ForgotPasswordState {
  const ForgotPasswordFailed(this.kind);

  final ForgotPasswordFailureKind kind;

  @override
  bool operator ==(Object other) =>
      other is ForgotPasswordFailed && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

enum ForgotPasswordFailureKind { rateLimited, network, unknown }
