import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/flow.dart';
import '../../domain/entities/step.dart' as fdom;
import '../../domain/failures/flows_failure.dart';
import '../../domain/repositories/flows_repository.dart';

/// Bloc del detalle de un flow (S11). Vida atada a la ruta `/flows/:id`:
/// se construye con el id y arranca en `Loading` para no flashear
/// Initial.
///
/// Paraleliza dos GETs (`flowById` + `listSteps`) con `Future.wait` —
/// el wire del backend NO anida los steps en el flow, así que en F2
/// hay dos endpoints. Si cualquiera falla, el bloc emite Failed con
/// ese failure y descarta el progreso del otro: la página no puede
/// mostrar half-state (cabecera sin steps o viceversa) sin confundir
/// al operador.
class FlowDetailBloc extends Bloc<FlowDetailEvent, FlowDetailState> {
  FlowDetailBloc({required FlowsRepository repo, required String id})
    : _repo = repo,
      _id = id,
      super(const FlowDetailLoading()) {
    on<FlowDetailLoadRequested>(_onLoad);
  }

  final FlowsRepository _repo;
  final String _id;

  Future<void> _onLoad(
    FlowDetailLoadRequested event,
    Emitter<FlowDetailState> emit,
  ) async {
    if (state is! FlowDetailLoading) {
      emit(const FlowDetailLoading());
    }
    try {
      final results = await Future.wait<dynamic>([
        _repo.flowById(_id),
        _repo.listSteps(_id),
      ]);
      final flow = results[0] as Flow;
      final steps = results[1] as List<fdom.Step>;
      emit(FlowDetailLoaded(flow, steps));
    } on FlowsFailure catch (f) {
      emit(FlowDetailFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class FlowDetailEvent {
  const FlowDetailEvent();
}

class FlowDetailLoadRequested extends FlowDetailEvent {
  const FlowDetailLoadRequested();
  @override
  bool operator ==(Object other) => other is FlowDetailLoadRequested;
  @override
  int get hashCode => (FlowDetailLoadRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class FlowDetailState {
  const FlowDetailState();
}

class FlowDetailLoading extends FlowDetailState {
  const FlowDetailLoading();
  @override
  bool operator ==(Object other) => other is FlowDetailLoading;
  @override
  int get hashCode => (FlowDetailLoading).hashCode;
}

class FlowDetailLoaded extends FlowDetailState {
  const FlowDetailLoaded(this.flow, this.steps);

  final Flow flow;
  final List<fdom.Step> steps;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowDetailLoaded) return false;
    if (other.flow != flow) return false;
    if (other.steps.length != steps.length) return false;
    for (var i = 0; i < steps.length; i++) {
      if (other.steps[i] != steps[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(flow, Object.hashAll(steps));
}

class FlowDetailFailed extends FlowDetailState {
  const FlowDetailFailed(this.failure);

  final FlowsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is FlowDetailFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
