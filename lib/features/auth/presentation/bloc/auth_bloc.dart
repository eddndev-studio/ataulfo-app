import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/identity.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// Bloc global de sesión: única fuente de verdad del estado de autenticación
/// que el router y la UI consumen para decidir ruta.
///
/// El bloc no toca storage directamente; toda I/O persistente y de red pasa
/// por `AuthRepository`. Eso lo hace testable contra un mock del puerto.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repo) : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheck);
    on<AuthLoggedOut>(_onLoggedOut);
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
    try {
      final identity = await _repo.me();
      // Sin org activa (usuario multi-membership con ninguna elegida) el
      // router lo desvía a la selección en vez del home; el estado distingue
      // los dos casos para que ese redirect no dependa de inspeccionar la
      // identity desde el router.
      emit(
        identity.hasActiveOrg
            ? AuthAuthenticated(identity)
            : AuthAuthenticatedNoOrg(identity),
      );
    } on NetworkFailure {
      // Hay tokens persistidos pero la verificación no llegó al servidor por
      // falta de red. NO es un cierre de sesión: los tokens siguen guardados.
      // Se entra a un estado de reconexión (el router muestra una vista que
      // reintenta al volver la red) en vez de mandar al login y aparentar que
      // la sesión se perdió. Cualquier otro fallo SÍ es rechazo real de sesión.
      emit(const AuthOfflinePending());
    } on AuthFailure {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLoggedOut(
    AuthLoggedOut event,
    Emitter<AuthState> emit,
  ) async {
    await _repo.logout();
    emit(const AuthUnauthenticated());
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

class AuthLoggedOut extends AuthEvent {
  const AuthLoggedOut();

  @override
  bool operator ==(Object other) => other is AuthLoggedOut;

  @override
  int get hashCode => (AuthLoggedOut).hashCode;
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

/// Sesión válida pero SIN org activa: el usuario tiene varias memberships y
/// no ha elegido ninguna (los claims llegan con `org_id`/`role` vacíos). El
/// router lo desvía a la selección de organización; no es admin de nada
/// porque no hay `role` org-scoped vigente. Estado separado de
/// `AuthAuthenticated` (no subtipo) para que los consumidores que chequean
/// `is AuthAuthenticated` lo traten como "autenticado sin privilegios".
class AuthAuthenticatedNoOrg extends AuthState {
  const AuthAuthenticatedNoOrg(this.identity);

  final Identity identity;

  @override
  bool operator ==(Object other) =>
      other is AuthAuthenticatedNoOrg && other.identity == identity;

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

/// Hay una sesión persistida pero no se pudo verificar contra el servidor por
/// falta de red. NO es un cierre de sesión: los tokens siguen guardados y el
/// arranque reintenta al volver la conexión. Estado separado de
/// `AuthUnauthenticated` para que el router muestre una vista de reconexión en
/// lugar del login, que daría a entender —falsamente— que la sesión se perdió.
class AuthOfflinePending extends AuthState {
  const AuthOfflinePending();

  @override
  bool operator ==(Object other) => other is AuthOfflinePending;

  @override
  int get hashCode => (AuthOfflinePending).hashCode;
}
