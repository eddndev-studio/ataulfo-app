import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// Cubit de renombrado de la org activa. Acción única: aplicar un nombre nuevo.
/// No toca tokens (el id de la org no cambia). NO conoce al AuthBloc ni a la
/// navegación: la página cierra el lazo (al éxito recarga el nombre fresco
/// re-listando memberships). Cada acción emite `Renaming` antes de la espera,
/// de modo que dos fallos idénticos seguidos siguen siendo transiciones
/// distintas para el listener.
class RenameOrgCubit extends Cubit<RenameOrgState> {
  RenameOrgCubit(this._repo) : super(const RenameOrgIdle());

  final AuthRepository _repo;

  Future<void> rename(String name) async {
    emit(const RenameOrgRenaming());
    try {
      await _repo.renameOrganization(name);
      emit(const RenameOrgRenamed());
    } on AuthFailure catch (f) {
      emit(RenameOrgFailed(f));
    }
  }
}

// States --------------------------------------------------------------------

sealed class RenameOrgState {
  const RenameOrgState();
}

class RenameOrgIdle extends RenameOrgState {
  const RenameOrgIdle();
  @override
  bool operator ==(Object other) => other is RenameOrgIdle;
  @override
  int get hashCode => (RenameOrgIdle).hashCode;
}

class RenameOrgRenaming extends RenameOrgState {
  const RenameOrgRenaming();
  @override
  bool operator ==(Object other) => other is RenameOrgRenaming;
  @override
  int get hashCode => (RenameOrgRenaming).hashCode;
}

class RenameOrgRenamed extends RenameOrgState {
  const RenameOrgRenamed();
  @override
  bool operator ==(Object other) => other is RenameOrgRenamed;
  @override
  int get hashCode => (RenameOrgRenamed).hashCode;
}

class RenameOrgFailed extends RenameOrgState {
  const RenameOrgFailed(this.failure);

  final AuthFailure failure;

  @override
  bool operator ==(Object other) =>
      other is RenameOrgFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}
