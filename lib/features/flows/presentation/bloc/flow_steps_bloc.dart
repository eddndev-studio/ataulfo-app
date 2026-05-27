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
///
/// Patrón de mutación: cada Add/Update/Delete sigue Mutating(snapshot) →
/// éxito ⇒ Loading + refetch + Loaded(refrescado); failure ⇒
/// MutationFailed(snapshot, failure) para que la UI muestre el error sin
/// tirar la lista actual. A diferencia de var-defs, no hay CAS — los
/// endpoints de step no exponen version del flow padre.
class FlowStepsBloc extends Bloc<FlowStepsEvent, FlowStepsState> {
  FlowStepsBloc({required FlowsRepository repo, required String flowId})
    : _repo = repo,
      _flowId = flowId,
      super(const FlowStepsLoading()) {
    on<FlowStepsLoadRequested>(_onLoad);
    on<FlowStepsAddRequested>(_onAdd);
    on<FlowStepsUpdateRequested>(_onUpdate);
    on<FlowStepsDeleteRequested>(_onDelete);
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

  Future<void> _onAdd(
    FlowStepsAddRequested event,
    Emitter<FlowStepsState> emit,
  ) async {
    await _runMutation(emit, (snapshot) async {
      await _repo.createStep(
        flowId: _flowId,
        type: fdom.StepType.text,
        order: snapshot.length,
        content: event.content,
        mediaRef: '',
        delayMs: event.delayMs,
        jitterPct: event.jitterPct,
        aiOnly: event.aiOnly,
      );
    });
  }

  Future<void> _onUpdate(
    FlowStepsUpdateRequested event,
    Emitter<FlowStepsState> emit,
  ) async {
    await _runMutation(emit, (_) async {
      await _repo.patchStep(
        stepId: event.stepId,
        content: event.content,
        delayMs: event.delayMs,
        jitterPct: event.jitterPct,
        aiOnly: event.aiOnly,
      );
    });
  }

  Future<void> _onDelete(
    FlowStepsDeleteRequested event,
    Emitter<FlowStepsState> emit,
  ) async {
    await _runMutation(emit, (_) async {
      await _repo.deleteStep(event.stepId);
    });
  }

  /// Orquesta una mutación de step:
  /// 1. lee snapshot vigente (Loaded o MutationFailed) — desde
  ///    Loading/Failed/Mutating ignora silenciosamente,
  /// 2. emit Mutating(snapshot),
  /// 3. corre `mutate(snapshot)` — failure ⇒ MutationFailed(snapshot, f),
  /// 4. emit Loading + refetch — failure del refetch ⇒ Failed (la
  ///    mutación SÍ fue persistida; no enmascarar como MutationFailed
  ///    porque el snapshot ya está obsoleto).
  Future<void> _runMutation(
    Emitter<FlowStepsState> emit,
    Future<void> Function(List<fdom.Step> snapshot) mutate,
  ) async {
    final current = state;
    final List<fdom.Step> snapshot;
    if (current is FlowStepsLoaded) {
      snapshot = current.steps;
    } else if (current is FlowStepsMutationFailed) {
      snapshot = current.steps;
    } else {
      return;
    }

    emit(FlowStepsMutating(snapshot));
    try {
      await mutate(snapshot);
    } on FlowsFailure catch (f) {
      emit(FlowStepsMutationFailed(snapshot, f));
      return;
    }
    emit(const FlowStepsLoading());
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

/// Pide agregar un step nuevo al final de la lista. El bloc resuelve el
/// `order` (= longitud del snapshot vigente) — el usuario no decide
/// posición al crear; reorder es una operación distinta. En F5a el tipo
/// se fija a TEXT; F6 expondrá la selección de tipo al crear.
class FlowStepsAddRequested extends FlowStepsEvent {
  const FlowStepsAddRequested({
    required this.content,
    required this.delayMs,
    required this.jitterPct,
    required this.aiOnly,
  });

  final String content;
  final int delayMs;
  final int jitterPct;
  final bool aiOnly;

  @override
  bool operator ==(Object other) =>
      other is FlowStepsAddRequested &&
      other.content == content &&
      other.delayMs == delayMs &&
      other.jitterPct == jitterPct &&
      other.aiOnly == aiOnly;

  @override
  int get hashCode => Object.hash(content, delayMs, jitterPct, aiOnly);
}

/// Pide editar un step (partial update). Cualquier campo `null` se omite
/// del PATCH — preservar = omitir. La UI computa el diff contra el step
/// original antes de despachar; si nada cambió, no debería despachar el
/// evento. El bloc no re-valida no-op (asume que la UI hizo su trabajo).
class FlowStepsUpdateRequested extends FlowStepsEvent {
  const FlowStepsUpdateRequested({
    required this.stepId,
    this.content,
    this.delayMs,
    this.jitterPct,
    this.aiOnly,
  });

  final String stepId;
  final String? content;
  final int? delayMs;
  final int? jitterPct;
  final bool? aiOnly;

  @override
  bool operator ==(Object other) =>
      other is FlowStepsUpdateRequested &&
      other.stepId == stepId &&
      other.content == content &&
      other.delayMs == delayMs &&
      other.jitterPct == jitterPct &&
      other.aiOnly == aiOnly;

  @override
  int get hashCode =>
      Object.hash(stepId, content, delayMs, jitterPct, aiOnly);
}

/// Pide eliminar un step. La operación es idempotente en el backend,
/// así que el bloc no necesita gates especiales — tras éxito el step
/// desaparece del refetch.
class FlowStepsDeleteRequested extends FlowStepsEvent {
  const FlowStepsDeleteRequested(this.stepId);

  final String stepId;

  @override
  bool operator ==(Object other) =>
      other is FlowStepsDeleteRequested && other.stepId == stepId;

  @override
  int get hashCode => stepId.hashCode;
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

/// Lista vigente durante una mutación. La UI muestra la lista intacta y
/// gates el botón de añadir / sheet en loading para evitar enviar dos
/// requests sobre el mismo snapshot.
class FlowStepsMutating extends FlowStepsState {
  const FlowStepsMutating(this.steps);

  final List<fdom.Step> steps;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowStepsMutating) return false;
    if (other.steps.length != steps.length) return false;
    for (var i = 0; i < steps.length; i++) {
      if (other.steps[i] != steps[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(steps);
}

/// Mutación falló pero la lista anterior sigue intacta — la UI reabre
/// el sheet o muestra snackbar para que el operador reintente con el
/// mismo o distinto input. Distinto de Failed (load), que es terminal.
class FlowStepsMutationFailed extends FlowStepsState {
  const FlowStepsMutationFailed(this.steps, this.failure);

  final List<fdom.Step> steps;
  final FlowsFailure failure;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowStepsMutationFailed) return false;
    if (other.failure != failure) return false;
    if (other.steps.length != steps.length) return false;
    for (var i = 0; i < steps.length; i++) {
      if (other.steps[i] != steps[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(failure, Object.hashAll(steps));
}
