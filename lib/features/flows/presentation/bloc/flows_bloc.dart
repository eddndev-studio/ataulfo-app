import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/flow.dart';
import '../../domain/failures/flows_failure.dart';
import '../../domain/repositories/flows_repository.dart';

/// Bloc del listado de flows de una Template (S11). Vida atada al
/// `TemplateDetailPage`: se construye con el templateId y arranca en
/// `Loading` para no flashear Initial. Sin mutaciones — F1 es read-only;
/// los slices de crear/editar/borrar flow extienden este bloc o montan
/// un editor dedicado, según el caso.
///
/// Separado del `TemplateDetailBloc` y del `VarDefsBloc` a propósito:
/// cada sección de la página gestiona su propio failure sin ocultar el
/// resto (un 503 cargando flows NO debe esconder el detalle de la
/// plantilla ni el listado de variables).
class FlowsBloc extends Bloc<FlowsEvent, FlowsState> {
  FlowsBloc({required FlowsRepository repo, required String templateId})
    : _repo = repo,
      _templateId = templateId,
      super(const FlowsLoading()) {
    on<FlowsLoadRequested>(_onLoad);
  }

  final FlowsRepository _repo;
  final String _templateId;

  Future<void> _onLoad(
    FlowsLoadRequested event,
    Emitter<FlowsState> emit,
  ) async {
    if (state is! FlowsLoading) {
      emit(const FlowsLoading());
    }
    try {
      final flows = await _repo.listFlows(_templateId);
      emit(FlowsLoaded(flows));
    } on FlowsFailure catch (f) {
      emit(FlowsFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class FlowsEvent {
  const FlowsEvent();
}

class FlowsLoadRequested extends FlowsEvent {
  const FlowsLoadRequested();
  @override
  bool operator ==(Object other) => other is FlowsLoadRequested;
  @override
  int get hashCode => (FlowsLoadRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class FlowsState {
  const FlowsState();
}

class FlowsLoading extends FlowsState {
  const FlowsLoading();
  @override
  bool operator ==(Object other) => other is FlowsLoading;
  @override
  int get hashCode => (FlowsLoading).hashCode;
}

class FlowsLoaded extends FlowsState {
  const FlowsLoaded(this.flows);

  final List<Flow> flows;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowsLoaded) return false;
    if (other.flows.length != flows.length) return false;
    for (var i = 0; i < flows.length; i++) {
      if (other.flows[i] != flows[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(flows);
}

class FlowsFailed extends FlowsState {
  const FlowsFailed(this.failure);

  final FlowsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is FlowsFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
