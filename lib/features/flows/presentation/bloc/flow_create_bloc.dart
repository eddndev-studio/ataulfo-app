import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/flow.dart';
import '../../domain/failures/flows_failure.dart';
import '../../domain/repositories/flows_repository.dart';

/// Bloc del flujo "crear flujo dentro de una Template". Mapea la acción
/// del usuario a `repo.createFlow(templateId, name)` y expone estados
/// que la UI consume directamente.
///
/// Las failures se exponen tal cual sin enum intermedio: la UI hace el
/// switch exhaustivo sobre `FlowsFailure` y elige copy (el sealed
/// fuerza al compilador a cubrir las variantes). Sin estado intermedio
/// para `name` — el form es controlado por la UI; el bloc sólo conoce
/// la submission.
class FlowCreateBloc extends Bloc<FlowCreateEvent, FlowCreateState> {
  FlowCreateBloc({required FlowsRepository repo, required String templateId})
    : _repo = repo,
      _templateId = templateId,
      super(const FlowCreateInitial()) {
    on<FlowCreateSubmitted>(_onSubmitted);
  }

  final FlowsRepository _repo;
  final String _templateId;

  Future<void> _onSubmitted(
    FlowCreateSubmitted event,
    Emitter<FlowCreateState> emit,
  ) async {
    emit(const FlowCreateSubmitting());
    try {
      final flow = await _repo.createFlow(
        templateId: _templateId,
        name: event.name,
      );
      emit(FlowCreateSucceeded(flow));
    } on FlowsFailure catch (f) {
      emit(FlowCreateFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class FlowCreateEvent {
  const FlowCreateEvent();
}

class FlowCreateSubmitted extends FlowCreateEvent {
  const FlowCreateSubmitted({required this.name});

  final String name;

  @override
  bool operator ==(Object other) =>
      other is FlowCreateSubmitted && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

// States --------------------------------------------------------------------

sealed class FlowCreateState {
  const FlowCreateState();
}

class FlowCreateInitial extends FlowCreateState {
  const FlowCreateInitial();
  @override
  bool operator ==(Object other) => other is FlowCreateInitial;
  @override
  int get hashCode => (FlowCreateInitial).hashCode;
}

class FlowCreateSubmitting extends FlowCreateState {
  const FlowCreateSubmitting();
  @override
  bool operator ==(Object other) => other is FlowCreateSubmitting;
  @override
  int get hashCode => (FlowCreateSubmitting).hashCode;
}

class FlowCreateSucceeded extends FlowCreateState {
  const FlowCreateSucceeded(this.flow);

  final Flow flow;

  @override
  bool operator ==(Object other) =>
      other is FlowCreateSucceeded && other.flow == flow;

  @override
  int get hashCode => flow.hashCode;
}

class FlowCreateFailed extends FlowCreateState {
  const FlowCreateFailed(this.failure);

  final FlowsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is FlowCreateFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
