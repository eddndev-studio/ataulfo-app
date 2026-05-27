import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/flow.dart';
import '../../domain/failures/flows_failure.dart';
import '../../domain/repositories/flows_repository.dart';

/// Bloc del detalle de un flow (S11). Vida atada a la ruta `/flows/:id`:
/// se construye con el id y arranca en `Loading` para no flashear
/// Initial.
///
/// Sostiene únicamente la cabecera del flow. La lista de Steps vive en
/// `FlowStepsBloc` (tab Pasos), Triggers vivirán en `TriggersBloc` y
/// la configuración en su propio bloc — cada tab del editor administra
/// su propio fetch y sus mutaciones de forma independiente.
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
      final flow = await _repo.flowById(_id);
      emit(FlowDetailLoaded(flow));
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
  const FlowDetailLoaded(this.flow);

  final Flow flow;

  @override
  bool operator ==(Object other) =>
      other is FlowDetailLoaded && other.flow == flow;

  @override
  int get hashCode => flow.hashCode;
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
