import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/invitations_failure.dart';
import '../../domain/repositories/invitations_repository.dart';

/// Cubit de las mutaciones de invitaciones (emitir, cancelar). Puede vivir en
/// la página para cancelar o dentro del sheet para crear; no conoce navegación
/// ni el bloc del listado. Cada acción emite `InProgress` antes de la espera,
/// de modo que dos fallos idénticos seguidos siguen siendo transiciones
/// distintas.
class InvitationMutationCubit extends Cubit<InvitationMutationState> {
  InvitationMutationCubit(this._repo) : super(const InvitationMutationIdle());

  final InvitationsRepository _repo;

  /// Limpia un resultado previo cuando la persona corrige el borrador.
  void reset() {
    if (state is! InvitationMutationIdle) {
      emit(const InvitationMutationIdle());
    }
  }

  Future<void> create(String email, String role, List<String> botIds) async {
    emit(const InvitationMutationInProgress());
    try {
      final created = await _repo.create(email, role, botIds);
      emit(
        InvitationMutationSuccess(
          InvitationMutationAction.created,
          email: email,
          token: created.token,
          emailSent: created.emailSent,
        ),
      );
    } on InvitationsFailure catch (f) {
      emit(InvitationMutationFailure(f));
    }
  }

  Future<void> cancel(String id) async {
    emit(const InvitationMutationInProgress());
    try {
      await _repo.cancel(id);
      emit(const InvitationMutationSuccess(InvitationMutationAction.canceled));
    } on InvitationsFailure catch (f) {
      emit(InvitationMutationFailure(f));
    }
  }
}

/// Qué mutación terminó bien — la página elige el copy del aviso por esto.
enum InvitationMutationAction { created, canceled }

// States --------------------------------------------------------------------

sealed class InvitationMutationState {
  const InvitationMutationState();
}

class InvitationMutationIdle extends InvitationMutationState {
  const InvitationMutationIdle();

  @override
  bool operator ==(Object other) => other is InvitationMutationIdle;
  @override
  int get hashCode => (InvitationMutationIdle).hashCode;
}

class InvitationMutationInProgress extends InvitationMutationState {
  const InvitationMutationInProgress();

  @override
  bool operator ==(Object other) => other is InvitationMutationInProgress;
  @override
  int get hashCode => (InvitationMutationInProgress).hashCode;
}

class InvitationMutationSuccess extends InvitationMutationState {
  const InvitationMutationSuccess(
    this.action, {
    this.email,
    this.token,
    this.emailSent = false,
  });

  final InvitationMutationAction action;

  /// Correo invitado — sólo presente en `created`, para el copy del aviso.
  final String? email;

  /// Token crudo a compartir — sólo en `created`. Nulo si el backend no lo
  /// devolvió (degrada a "revisa el correo" sin código copiable).
  final String? token;

  /// Si el correo de invitación salió — sólo en `created`, para ser honesto.
  final bool emailSent;

  @override
  bool operator ==(Object other) =>
      other is InvitationMutationSuccess &&
      other.action == action &&
      other.email == email &&
      other.token == token &&
      other.emailSent == emailSent;
  @override
  int get hashCode => Object.hash(action, email, token, emailSent);
}

class InvitationMutationFailure extends InvitationMutationState {
  const InvitationMutationFailure(this.failure);

  final InvitationsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is InvitationMutationFailure && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}
