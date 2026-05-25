import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/variable_def.dart';
import '../../domain/failures/templates_failure.dart';
import '../../domain/repositories/templates_repository.dart';

/// Bloc del listado de variable-definitions de una Template (S03).
/// Vida del bloc atada a la ruta `/templates/:id`: se construye con el
/// templateId y arranca en `Loading` para no flashear Initial.
///
/// Separado del `TemplateDetailBloc` a propósito: una falla cargando las
/// var-defs NO debe ocultar el detalle de la plantilla (header, AIConfig,
/// prompt). El operador ve la Template y la sección "Variables" expone su
/// propio estado de error con retry.
class VarDefsBloc extends Bloc<VarDefsEvent, VarDefsState> {
  VarDefsBloc({required TemplatesRepository repo, required String templateId})
    : _repo = repo,
      _templateId = templateId,
      super(const VarDefsLoading()) {
    on<VarDefsLoadRequested>(_onLoad);
  }

  final TemplatesRepository _repo;
  final String _templateId;

  Future<void> _onLoad(
    VarDefsLoadRequested event,
    Emitter<VarDefsState> emit,
  ) async {
    if (state is! VarDefsLoading) {
      emit(const VarDefsLoading());
    }
    try {
      final defs = await _repo.listVarDefs(_templateId);
      emit(VarDefsLoaded(defs));
    } on TemplatesFailure catch (f) {
      emit(VarDefsFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class VarDefsEvent {
  const VarDefsEvent();
}

class VarDefsLoadRequested extends VarDefsEvent {
  const VarDefsLoadRequested();
  @override
  bool operator ==(Object other) => other is VarDefsLoadRequested;
  @override
  int get hashCode => (VarDefsLoadRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class VarDefsState {
  const VarDefsState();
}

class VarDefsLoading extends VarDefsState {
  const VarDefsLoading();
  @override
  bool operator ==(Object other) => other is VarDefsLoading;
  @override
  int get hashCode => (VarDefsLoading).hashCode;
}

class VarDefsLoaded extends VarDefsState {
  const VarDefsLoaded(this.defs);

  final List<VariableDef> defs;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VarDefsLoaded) return false;
    if (other.defs.length != defs.length) return false;
    for (var i = 0; i < defs.length; i++) {
      if (other.defs[i] != defs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(defs);
}

class VarDefsFailed extends VarDefsState {
  const VarDefsFailed(this.failure);

  final TemplatesFailure failure;

  @override
  bool operator ==(Object other) =>
      other is VarDefsFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}
