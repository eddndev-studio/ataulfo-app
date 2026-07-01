import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_tokens.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// Mínimo de longitud de contraseña que exige el backend en `/auth/register`.
/// El cliente lo valida antes de pegar al servidor para dar feedback inmediato;
/// el backend sigue siendo la autoridad (un `WeakPasswordFailure` 400 también
/// se mapea a `passwordTooShort`).
const int _minPasswordLength = 12;

/// Bloc del alta de cuenta. Espejo de `LoginBloc`: mapea la acción del usuario
/// a la llamada al repositorio y expone estados que la UI consume directo.
///
/// La validación de cliente (campos vacíos, longitud, coincidencia de la
/// confirmación) ocurre ANTES de llamar al repositorio: un envío inválido no
/// gasta un viaje al backend y devuelve un `RegisterFailed` con la causa
/// concreta. La página es la única dueña del gate de habilitación del botón;
/// el bloc es la única autoridad de validación.
class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc(this._repo) : super(const RegisterInitial()) {
    on<RegisterSubmitted>(_onSubmitted);
  }

  final AuthRepository _repo;

  Future<void> _onSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    if (event.email.isEmpty ||
        event.password.isEmpty ||
        event.confirmPassword.isEmpty) {
      emit(const RegisterFailed(RegisterFailureKind.invalidInput));
      return;
    }
    if (event.password.length < _minPasswordLength) {
      emit(const RegisterFailed(RegisterFailureKind.passwordTooShort));
      return;
    }
    if (event.password != event.confirmPassword) {
      emit(const RegisterFailed(RegisterFailureKind.passwordMismatch));
      return;
    }
    emit(const RegisterSubmitting());
    try {
      final tokens = await _repo.register(
        email: event.email,
        password: event.password,
      );
      emit(RegisterSucceeded(tokens));
    } on AuthFailure catch (e) {
      emit(RegisterFailed(_kindOf(e)));
    }
  }

  RegisterFailureKind _kindOf(AuthFailure e) => switch (e) {
    EmailTakenFailure() => RegisterFailureKind.emailTaken,
    WeakPasswordFailure() => RegisterFailureKind.passwordTooShort,
    RateLimitedFailure() => RegisterFailureKind.rateLimited,
    NetworkFailure() => RegisterFailureKind.network,
    // Las variantes de otros endpoints del arco de auth (login, verificación,
    // reset, switch-org, accept) no pueden surgir contra `/auth/register`; el
    // alta no las distingue y las colapsa a genérico.
    InvalidCredentialsFailure() ||
    InvalidTokenFailure() ||
    ExpiredTokenFailure() ||
    EmailMismatchFailure() ||
    AlreadyMemberFailure() ||
    NotMemberFailure() ||
    EmailNotVerifiedFailure() ||
    UnknownAuthFailure() => RegisterFailureKind.unknown,
  };
}

// Events --------------------------------------------------------------------

sealed class RegisterEvent {
  const RegisterEvent();
}

class RegisterSubmitted extends RegisterEvent {
  const RegisterSubmitted({
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  final String email;
  final String password;
  final String confirmPassword;

  @override
  bool operator ==(Object other) =>
      other is RegisterSubmitted &&
      other.email == email &&
      other.password == password &&
      other.confirmPassword == confirmPassword;

  @override
  int get hashCode => Object.hash(email, password, confirmPassword);
}

// States --------------------------------------------------------------------

sealed class RegisterState {
  const RegisterState();
}

class RegisterInitial extends RegisterState {
  const RegisterInitial();

  @override
  bool operator ==(Object other) => other is RegisterInitial;

  @override
  int get hashCode => (RegisterInitial).hashCode;
}

class RegisterSubmitting extends RegisterState {
  const RegisterSubmitting();

  @override
  bool operator ==(Object other) => other is RegisterSubmitting;

  @override
  int get hashCode => (RegisterSubmitting).hashCode;
}

class RegisterSucceeded extends RegisterState {
  const RegisterSucceeded(this.tokens);

  final AuthTokens tokens;

  @override
  bool operator ==(Object other) =>
      other is RegisterSucceeded && other.tokens == tokens;

  @override
  int get hashCode => tokens.hashCode;
}

class RegisterFailed extends RegisterState {
  const RegisterFailed(this.kind);

  final RegisterFailureKind kind;

  @override
  bool operator ==(Object other) =>
      other is RegisterFailed && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

enum RegisterFailureKind {
  invalidInput,
  passwordTooShort,
  passwordMismatch,
  emailTaken,
  rateLimited,
  network,
  unknown,
}
