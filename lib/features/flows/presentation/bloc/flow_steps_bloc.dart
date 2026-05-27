import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/step.dart' as fdom;
import '../../domain/failures/flows_failure.dart';
import '../../domain/repositories/flows_repository.dart';

/// Bloc de la lista de Steps de un Flow (S11). Vive en el tab "Pasos"
/// del editor; vida atada a la ruta `/flows/:id`. Arranca en `Loading`
/// para no flashear Initial.
///
/// Separado del `FlowDetailBloc` (que sostiene la cabecera del flow)
/// porque las mutaciones de steps (add / edit / delete / reorder) viven
/// solo en este tab — mantenerlas en el bloc del page mezclaría
/// responsabilidades de tres tabs independientes.
class FlowStepsBloc extends Bloc<FlowStepsEvent, FlowStepsState> {
  FlowStepsBloc({required FlowsRepository repo, required String flowId})
    : _repo = repo,
      _flowId = flowId,
      super(const FlowStepsLoading()) {
    on<FlowStepsLoadRequested>(_onLoad);
  }

  final FlowsRepository _repo;
  final String _flowId;

  Future<void> _onLoad(
    FlowStepsLoadRequested event,
    Emitter<FlowStepsState> emit,
  ) async {
    if (state is! FlowStepsLoading) {
      emit(const FlowStepsLoading());
    }
    try {
      final steps = await _repo.listSteps(_flowId);
      emit(FlowStepsLoaded(steps));
    } on FlowsFailure catch (f) {
      emit(FlowStepsFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class FlowStepsEvent {
  const FlowStepsEvent();
}

class FlowStepsLoadRequested extends FlowStepsEvent {
  const FlowStepsLoadRequested();
  @override
  bool operator ==(Object other) => other is FlowStepsLoadRequested;
  @override
  int get hashCode => (FlowStepsLoadRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class FlowStepsState {
  const FlowStepsState();
}

class FlowStepsLoading extends FlowStepsState {
  const FlowStepsLoading();
  @override
  bool operator ==(Object other) => other is FlowStepsLoading;
  @override
  int get hashCode => (FlowStepsLoading).hashCode;
}

class FlowStepsLoaded extends FlowStepsState {
  const FlowStepsLoaded(this.steps);

  final List<fdom.Step> steps;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowStepsLoaded) return false;
    if (other.steps.length != steps.length) return false;
    for (var i = 0; i < steps.length; i++) {
      if (other.steps[i] != steps[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(steps);
}

class FlowStepsFailed extends FlowStepsState {
  const FlowStepsFailed(this.failure);

  final FlowsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is FlowStepsFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
