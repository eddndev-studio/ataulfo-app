import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_tokens.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// Bloc del login. Mapea acciones del usuario a llamadas al repositorio y
/// expone estados que la UI consume directamente.
///
/// La ramificación a "elegir organización" cuando el access viene sin
/// `org_id` (S02: usuario con varias memberships) se modelará en un slice
/// posterior — exige un endpoint para listar las orgs del usuario que aún
/// no existe en el backend (`/auth/memberships`). Hasta entonces, el
/// `LoginSucceeded` no diferencia; la UI continuará al home y dependerá
/// del access tal cual venga del backend.
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc(this._repo) : super(const LoginInitial()) {
    on<LoginSubmitted>(_onSubmitted);
  }

  final AuthRepository _repo;

  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    if (event.email.isEmpty || event.password.isEmpty) {
      emit(const LoginFailed(LoginFailureKind.invalidInput));
      return;
    }
    emit(const LoginSubmitting());
    try {
      final tokens = await _repo.login(
        email: event.email,
        password: event.password,
      );
      emit(LoginSucceeded(tokens));
    } on AuthFailure catch (e) {
      emit(LoginFailed(_kindOf(e)));
    }
  }

  LoginFailureKind _kindOf(AuthFailure e) => switch (e) {
    InvalidCredentialsFailure() => LoginFailureKind.invalidCredentials,
    RateLimitedFailure() => LoginFailureKind.rateLimited,
    NetworkFailure() => LoginFailureKind.network,
    UnknownAuthFailure() => LoginFailureKind.unknown,
  };
}

// Events --------------------------------------------------------------------

sealed class LoginEvent {
  const LoginEvent();
}

class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({required this.email, required this.password});

  final String email;
  final String password;

  @override
  bool operator ==(Object other) =>
      other is LoginSubmitted &&
      other.email == email &&
      other.password == password;

  @override
  int get hashCode => Object.hash(email, password);
}

// States --------------------------------------------------------------------

sealed class LoginState {
  const LoginState();
}

class LoginInitial extends LoginState {
  const LoginInitial();

  @override
  bool operator ==(Object other) => other is LoginInitial;

  @override
  int get hashCode => (LoginInitial).hashCode;
}

class LoginSubmitting extends LoginState {
  const LoginSubmitting();

  @override
  bool operator ==(Object other) => other is LoginSubmitting;

  @override
  int get hashCode => (LoginSubmitting).hashCode;
}

class LoginSucceeded extends LoginState {
  const LoginSucceeded(this.tokens);

  final AuthTokens tokens;

  @override
  bool operator ==(Object other) =>
      other is LoginSucceeded && other.tokens == tokens;

  @override
  int get hashCode => tokens.hashCode;
}

class LoginFailed extends LoginState {
  const LoginFailed(this.kind);

  final LoginFailureKind kind;

  @override
  bool operator ==(Object other) =>
      other is LoginFailed && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

enum LoginFailureKind {
  invalidInput,
  invalidCredentials,
  rateLimited,
  network,
  unknown,
}
