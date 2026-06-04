import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// Cubit de creación de organización. Acción única: pedir al backend una org
/// nueva con un nombre. El repo persiste el par devuelto (la org nueva queda
/// activa), igual que el switch-org; este cubit NO conoce al AuthBloc ni a la
/// navegación: la página cierra el lazo (releer `/auth/me` y rutear al shell).
class CreateOrgCubit extends Cubit<CreateOrgState> {
  CreateOrgCubit(this._repo) : super(const CreateOrgIdle());

  final AuthRepository _repo;

  Future<void> create(String name) async {
    emit(const CreateOrgCreating());
    try {
      await _repo.createOrganization(name);
      emit(const CreateOrgCreated());
    } on AuthFailure catch (f) {
      emit(CreateOrgFailed(f));
    }
  }
}

// States --------------------------------------------------------------------

sealed class CreateOrgState {
  const CreateOrgState();
}

class CreateOrgIdle extends CreateOrgState {
  const CreateOrgIdle();
  @override
  bool operator ==(Object other) => other is CreateOrgIdle;
  @override
  int get hashCode => (CreateOrgIdle).hashCode;
}

class CreateOrgCreating extends CreateOrgState {
  const CreateOrgCreating();
  @override
  bool operator ==(Object other) => other is CreateOrgCreating;
  @override
  int get hashCode => (CreateOrgCreating).hashCode;
}

class CreateOrgCreated extends CreateOrgState {
  const CreateOrgCreated();
  @override
  bool operator ==(Object other) => other is CreateOrgCreated;
  @override
  int get hashCode => (CreateOrgCreated).hashCode;
}

class CreateOrgFailed extends CreateOrgState {
  const CreateOrgFailed(this.failure);

  final AuthFailure failure;

  @override
  bool operator ==(Object other) =>
      other is CreateOrgFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}
