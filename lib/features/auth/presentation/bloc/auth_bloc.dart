import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/identity.dart';
import '../../domain/repositories/auth_repository.dart';

/// Bloc global de sesión: única fuente de verdad del estado de autenticación
/// que el router y la UI consumen para decidir ruta.
///
/// El bloc no toca storage directamente; toda I/O persistente y de red pasa
/// por `AuthRepository`. Eso lo hace testable contra un mock del puerto.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repo) : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheck);
  }

  final AuthRepository _repo;

  Future<void> _onCheck(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!await _repo.hasTokens()) {
      emit(const AuthUnauthenticated());
      return;
    }
    final identity = await _repo.me();
    emit(AuthAuthenticated(identity));
  }
}

// Events --------------------------------------------------------------------

sealed class AuthEvent {
  const AuthEvent();
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();

  @override
  bool operator ==(Object other) => other is AuthCheckRequested;

  @override
  int get hashCode => (AuthCheckRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();

  @override
  bool operator ==(Object other) => other is AuthInitial;

  @override
  int get hashCode => (AuthInitial).hashCode;
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.identity);

  final Identity identity;

  @override
  bool operator ==(Object other) =>
      other is AuthAuthenticated && other.identity == identity;

  @override
  int get hashCode => identity.hashCode;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();

  @override
  bool operator ==(Object other) => other is AuthUnauthenticated;

  @override
  int get hashCode => (AuthUnauthenticated).hashCode;
}
