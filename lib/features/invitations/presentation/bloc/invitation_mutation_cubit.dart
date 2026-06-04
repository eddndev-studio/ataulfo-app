import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/invitations_failure.dart';
import '../../domain/repositories/invitations_repository.dart';

/// Cubit de las mutaciones de invitaciones (emitir, cancelar). Vive scoped a la
/// página y NO conoce ni al bloc del listado ni a la navegación: ejecuta la
/// mutación vía el repo y reporta el resultado. La página cierra el lazo
/// (recargar el historial y avisar; ante 404/410 también recarga porque la
/// lista local quedó stale). Cada acción emite `InProgress` antes de la espera,
/// de modo que dos fallos idénticos seguidos siguen siendo transiciones
/// distintas.
class InvitationMutationCubit extends Cubit<InvitationMutationState> {
  InvitationMutationCubit(this._repo) : super(const InvitationMutationIdle());

  final InvitationsRepository _repo;

  Future<void> create(String email, String role) async {
    emit(const InvitationMutationInProgress());
    try {
      await _repo.create(email, role);
      emit(
        InvitationMutationSuccess(
          InvitationMutationAction.created,
          email: email,
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
  const InvitationMutationSuccess(this.action, {this.email});

  final InvitationMutationAction action;

  /// Correo invitado — sólo presente en `created`, para el copy del aviso.
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is InvitationMutationSuccess &&
      other.action == action &&
      other.email == email;
  @override
  int get hashCode => Object.hash(action, email);
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
