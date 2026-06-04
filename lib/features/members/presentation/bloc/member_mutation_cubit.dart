import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/members_failure.dart';
import '../../domain/repositories/members_repository.dart';

/// Cubit de las mutaciones sobre un miembro (cambiar rol, quitar). Vive scoped
/// a la página de miembros y NO conoce ni al bloc del listado ni a la
/// navegación: sólo ejecuta la mutación vía el repo y reporta el resultado.
///
/// La página cierra el lazo: ante `Success` recarga el listado y avisa; ante
/// `Failure` traduce la causa a copy. Cada acción emite `InProgress` antes de
/// la espera, de modo que dos fallos idénticos seguidos siguen siendo
/// transiciones distintas (el listener no se los pierde por igualdad de estado).
class MemberMutationCubit extends Cubit<MemberMutationState> {
  MemberMutationCubit(this._repo) : super(const MemberMutationIdle());

  final MembersRepository _repo;

  Future<void> changeRole(String membershipId, String role) async {
    emit(const MemberMutationInProgress());
    try {
      await _repo.changeRole(membershipId, role);
      emit(const MemberMutationSuccess(MemberMutationAction.roleChanged));
    } on MembersFailure catch (f) {
      emit(MemberMutationFailure(f));
    }
  }

  Future<void> remove(String membershipId) async {
    emit(const MemberMutationInProgress());
    try {
      await _repo.removeMember(membershipId);
      emit(const MemberMutationSuccess(MemberMutationAction.removed));
    } on MembersFailure catch (f) {
      emit(MemberMutationFailure(f));
    }
  }

  Future<void> transfer(String membershipId) async {
    emit(const MemberMutationInProgress());
    try {
      await _repo.transferOwnership(membershipId);
      emit(
        const MemberMutationSuccess(MemberMutationAction.ownershipTransferred),
      );
    } on MembersFailure catch (f) {
      emit(MemberMutationFailure(f));
    }
  }
}

/// Qué mutación terminó bien — la página elige el copy del aviso por esto.
enum MemberMutationAction { roleChanged, removed, ownershipTransferred }

// States --------------------------------------------------------------------

sealed class MemberMutationState {
  const MemberMutationState();
}

class MemberMutationIdle extends MemberMutationState {
  const MemberMutationIdle();

  @override
  bool operator ==(Object other) => other is MemberMutationIdle;
  @override
  int get hashCode => (MemberMutationIdle).hashCode;
}

class MemberMutationInProgress extends MemberMutationState {
  const MemberMutationInProgress();

  @override
  bool operator ==(Object other) => other is MemberMutationInProgress;
  @override
  int get hashCode => (MemberMutationInProgress).hashCode;
}

class MemberMutationSuccess extends MemberMutationState {
  const MemberMutationSuccess(this.action);

  final MemberMutationAction action;

  @override
  bool operator ==(Object other) =>
      other is MemberMutationSuccess && other.action == action;
  @override
  int get hashCode => action.hashCode;
}

class MemberMutationFailure extends MemberMutationState {
  const MemberMutationFailure(this.failure);

  final MembersFailure failure;

  @override
  bool operator ==(Object other) =>
      other is MemberMutationFailure && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}
