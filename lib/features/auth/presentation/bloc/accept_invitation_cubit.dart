import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../util/pasted_token.dart';

/// Cubit de la aceptación de invitación. Toma lo que el operador pegó (el
/// enlace de la invitación o el token suelto), extrae el token y lo canjea
/// contra el backend con la sesión actual.
///
/// La invitación se canjea con el operador YA logueado: el backend valida que
/// el correo de la sesión coincida con el invitado. La validación de cliente
/// (token presente) ocurre ANTES de llamar al repositorio: un envío en blanco
/// no gasta un viaje al backend. El canje no inicia ni cambia la sesión —
/// devuelve sin la org nueva activa; la membership recién creada se activa con
/// un switch-org posterior, que esta capa no orquesta.
class AcceptInvitationCubit extends Cubit<AcceptInvitationState> {
  AcceptInvitationCubit(this._repo) : super(const AcceptInvitationIdle());

  final AuthRepository _repo;

  Future<void> accept(String rawText) async {
    final token = extractPastedToken(rawText);
    if (token.isEmpty) {
      emit(
        const AcceptInvitationFailed(AcceptInvitationFailureKind.invalidInput),
      );
      return;
    }
    emit(const AcceptInvitationAccepting());
    try {
      await _repo.acceptInvitation(token);
      emit(const AcceptInvitationAccepted());
    } on AuthFailure catch (e) {
      emit(AcceptInvitationFailed(_kindOf(e)));
    }
  }

  AcceptInvitationFailureKind _kindOf(AuthFailure e) => switch (e) {
    // El 404 (token inexistente/consumido) y el 410 (expirado) colapsan al
    // mismo copy de "inválida o expirada": el operador re-solicita la
    // invitación en ambos casos. `accept` no mapea 410 hoy, pero el switch
    // cubre la variante para no romperse si el contrato la añade.
    InvalidTokenFailure() => AcceptInvitationFailureKind.invalidToken,
    ExpiredTokenFailure() => AcceptInvitationFailureKind.invalidToken,
    // El backend responde 409 desnudo para "correo distinto" Y "ya miembro"
    // sin discriminar; el mapeo del datasource lo trae como EmailMismatch.
    EmailMismatchFailure() => AcceptInvitationFailureKind.emailMismatch,
    NetworkFailure() => AcceptInvitationFailureKind.network,
    // Las variantes de otros endpoints del arco de auth no pueden surgir
    // contra `/auth/invitations/accept`; se colapsan a genérico.
    InvalidCredentialsFailure() ||
    RateLimitedFailure() ||
    EmailTakenFailure() ||
    WeakPasswordFailure() ||
    AlreadyMemberFailure() ||
    NotMemberFailure() ||
    UnknownAuthFailure() => AcceptInvitationFailureKind.unknown,
  };
}

// States --------------------------------------------------------------------

sealed class AcceptInvitationState {
  const AcceptInvitationState();
}

class AcceptInvitationIdle extends AcceptInvitationState {
  const AcceptInvitationIdle();

  @override
  bool operator ==(Object other) => other is AcceptInvitationIdle;

  @override
  int get hashCode => (AcceptInvitationIdle).hashCode;
}

class AcceptInvitationAccepting extends AcceptInvitationState {
  const AcceptInvitationAccepting();

  @override
  bool operator ==(Object other) => other is AcceptInvitationAccepting;

  @override
  int get hashCode => (AcceptInvitationAccepting).hashCode;
}

/// Invitación aceptada (204). La membership nueva existe pero no está activa:
/// la UI dirige al operador a una superficie de switch para activarla.
class AcceptInvitationAccepted extends AcceptInvitationState {
  const AcceptInvitationAccepted();

  @override
  bool operator ==(Object other) => other is AcceptInvitationAccepted;

  @override
  int get hashCode => (AcceptInvitationAccepted).hashCode;
}

class AcceptInvitationFailed extends AcceptInvitationState {
  const AcceptInvitationFailed(this.kind);

  final AcceptInvitationFailureKind kind;

  @override
  bool operator ==(Object other) =>
      other is AcceptInvitationFailed && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

enum AcceptInvitationFailureKind {
  invalidInput,
  invalidToken,
  emailMismatch,
  network,
  unknown,
}
