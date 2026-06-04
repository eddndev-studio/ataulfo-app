import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// Cubit del cambio de organización activa. Acción única: pedir al backend el
/// switch a una org y persistir el nuevo par de tokens (lo hace el repo).
///
/// Vive scoped a la página que lo dispara y NO conoce ni al `AuthBloc` ni a la
/// navegación: sólo persiste vía el repo y reporta el resultado. El flip de la
/// sesión (releer `/auth/me`) y el ruteo los orquesta la página — así el cubit
/// se mantiene testeable contra un mock del puerto, sin acoplarse al router.
///
/// `Failed` lleva el `AuthFailure` para que la página distinga la causa: un
/// `NotMemberFailure` (membership revocada / org ajena) pide recargar la lista,
/// el resto es un reintento genérico.
class SwitchOrgCubit extends Cubit<SwitchOrgState> {
  SwitchOrgCubit(this._repo) : super(const SwitchOrgIdle());

  final AuthRepository _repo;

  Future<void> switchTo(String orgId) async {
    emit(const SwitchOrgSwitching());
    try {
      await _repo.switchOrg(orgId);
      emit(SwitchOrgSwitched(orgId));
    } on AuthFailure catch (f) {
      emit(SwitchOrgFailed(f));
    }
  }
}

// States --------------------------------------------------------------------

sealed class SwitchOrgState {
  const SwitchOrgState();
}

class SwitchOrgIdle extends SwitchOrgState {
  const SwitchOrgIdle();

  @override
  bool operator ==(Object other) => other is SwitchOrgIdle;

  @override
  int get hashCode => (SwitchOrgIdle).hashCode;
}

class SwitchOrgSwitching extends SwitchOrgState {
  const SwitchOrgSwitching();

  @override
  bool operator ==(Object other) => other is SwitchOrgSwitching;

  @override
  int get hashCode => (SwitchOrgSwitching).hashCode;
}

class SwitchOrgSwitched extends SwitchOrgState {
  const SwitchOrgSwitched(this.orgId);

  final String orgId;

  @override
  bool operator ==(Object other) =>
      other is SwitchOrgSwitched && other.orgId == orgId;

  @override
  int get hashCode => orgId.hashCode;
}

class SwitchOrgFailed extends SwitchOrgState {
  const SwitchOrgFailed(this.failure);

  final AuthFailure failure;

  @override
  bool operator ==(Object other) =>
      other is SwitchOrgFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
