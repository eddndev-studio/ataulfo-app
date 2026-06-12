// Supera 400 LOC porque coloca el bloc con sus eventos y estados sellados
// (patrón estándar de flutter_bloc): separarlos en archivos hermanos
// fragmentaría una unidad cohesiva sin reuso real. Si crece más, el primer
// corte es extraer eventos/estados a `flow_steps_event.dart`/`_state.dart`.
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/conditional_time_reorder.dart';
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
    on<FlowStepsReorderRequested>(_onReorder);
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
        type: event.type,
        order: snapshot.length,
        content: event.content,
        mediaRef: event.mediaRef,
        delayMs: event.delayMs,
        jitterPct: event.jitterPct,
        aiOnly: event.aiOnly,
        manualOnly: event.manualOnly,
        metadataJson: event.metadataJson,
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
        mediaRef: event.mediaRef,
        delayMs: event.delayMs,
        jitterPct: event.jitterPct,
        aiOnly: event.aiOnly,
        manualOnly: event.manualOnly,
        metadataJson: event.metadataJson,
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

  /// Reorder = N×PATCH /steps/:id cambiando `order`. Sin UNIQUE en
  /// `(flow_id, order)` no se requiere two-pass: cada patch viaja
  /// independiente. Se hace skip cuando el step ya estaba en su
  /// posición destino y no necesita remap, para no gastar requests en
  /// no-ops (ej. cuando la UX dispara reorder con el array entero aunque
  /// el operador haya soltado el item en su lugar original).
  ///
  /// Los pasos CONDITIONAL_TIME guardan sus destinos (`onMatchOrder`/
  /// `onElseOrder`) por posición; al reordenar hay que recomponerlos para
  /// que sigan apuntando al paso lógico (su id), o las flechas quedarían
  /// apuntando al paso equivocado en silencio. El remap puede tocar un CT
  /// que ni siquiera se movió (si sus destinos sí lo hicieron) y viaja en
  /// el mismo PATCH que el cambio de `order` cuando ambos aplican.
  ///
  /// Si una patch a mitad falla, el bloc deja el backend en estado
  /// parcial y emite MutationFailed(snapshot original, failure) — la
  /// UI puede ofrecer reload manual. No se refetch automático porque
  /// enmascarar el orden parcial con un Loaded "como si nada" engaña
  /// al operador.
  Future<void> _onReorder(
    FlowStepsReorderRequested event,
    Emitter<FlowStepsState> emit,
  ) async {
    await _runMutation(emit, (snapshot) async {
      final byId = <String, fdom.Step>{for (final s in snapshot) s.id: s};
      final ctRemap = remapConditionalTargetsOnReorder(snapshot, event.ids);
      for (var i = 0; i < event.ids.length; i++) {
        final id = event.ids[i];
        final original = byId[id];
        if (original == null) continue;
        final orderChanged = original.order != i;
        final newMetadataJson = ctRemap[id];
        if (!orderChanged && newMetadataJson == null) continue;
        await _repo.patchStep(
          stepId: id,
          order: orderChanged ? i : null,
          metadataJson: newMetadataJson,
        );
      }
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
/// posición al crear; reorder es una operación distinta.
///
/// `type` y `mediaRef` los elige el sheet: TEXT usa `mediaRef:''`; los
/// tipos multimedia (IMAGE/VIDEO/DOCUMENT/AUDIO/PTT/STICKER) viajan con
/// `mediaRef` no vacío y `content` opcional como caption. Defaults
/// `type:text` + `mediaRef:''` para callers que no necesitan elegir
/// (atajo del path TEXT sin tener que repetir los dos campos).
class FlowStepsAddRequested extends FlowStepsEvent {
  const FlowStepsAddRequested({
    required this.content,
    required this.delayMs,
    required this.jitterPct,
    required this.aiOnly,
    this.manualOnly = false,
    this.type = fdom.StepType.text,
    this.mediaRef = '',
    this.metadataJson,
  });

  final fdom.StepType type;
  final String mediaRef;
  final String content;
  final int delayMs;
  final int jitterPct;
  final bool aiOnly;

  /// Inverso de [aiOnly]: el paso solo corre por disparador/arranque manual.
  /// El selector del sheet garantiza que nunca viajen ambos en true.
  final bool manualOnly;

  /// Shape literal de `Step.metadata` para el step nuevo. Hoy lo necesita
  /// solo CONDITIONAL_TIME (ventanas); null para los otros tipos —el
  /// backend les pone `{}` por defecto.
  final String? metadataJson;

  @override
  bool operator ==(Object other) =>
      other is FlowStepsAddRequested &&
      other.type == type &&
      other.mediaRef == mediaRef &&
      other.content == content &&
      other.delayMs == delayMs &&
      other.jitterPct == jitterPct &&
      other.aiOnly == aiOnly &&
      other.manualOnly == manualOnly &&
      other.metadataJson == metadataJson;

  @override
  int get hashCode => Object.hash(
    type,
    mediaRef,
    content,
    delayMs,
    jitterPct,
    aiOnly,
    manualOnly,
    metadataJson,
  );
}

/// Pide editar un step (partial update). Cualquier campo `null` se omite
/// del PATCH — preservar = omitir. La UI computa el diff contra el step
/// original antes de despachar; si nada cambió, no debería despachar el
/// evento. El bloc no re-valida no-op (asume que la UI hizo su trabajo).
class FlowStepsUpdateRequested extends FlowStepsEvent {
  const FlowStepsUpdateRequested({
    required this.stepId,
    this.content,
    this.mediaRef,
    this.delayMs,
    this.jitterPct,
    this.aiOnly,
    this.manualOnly,
    this.metadataJson,
  });

  final String stepId;
  final String? content;

  /// Nuevo `ref` BARE del recurso multimedia cuando el operador lo
  /// reemplaza. Null = preservar el recurso actual (omitido del PATCH).
  /// Siempre el ref BARE canónico — jamás la URL firmada efímera.
  final String? mediaRef;
  final int? delayMs;
  final int? jitterPct;
  final bool? aiOnly;

  /// Cambio del modo "solo disparadores". Null = preservar (omitido).
  final bool? manualOnly;

  /// Nuevo shape de `Step.metadata` para el step. Null = preservar el
  /// metadata actual del backend (omitido del PATCH).
  final String? metadataJson;

  @override
  bool operator ==(Object other) =>
      other is FlowStepsUpdateRequested &&
      other.stepId == stepId &&
      other.content == content &&
      other.mediaRef == mediaRef &&
      other.delayMs == delayMs &&
      other.jitterPct == jitterPct &&
      other.aiOnly == aiOnly &&
      other.manualOnly == manualOnly &&
      other.metadataJson == metadataJson;

  @override
  int get hashCode => Object.hash(
    stepId,
    content,
    mediaRef,
    delayMs,
    jitterPct,
    aiOnly,
    manualOnly,
    metadataJson,
  );
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

/// Pide reordenar la lista de steps. `ids` es el array completo de
/// ids de step en el orden destino — el bloc compara contra el
/// snapshot vigente y dispara PATCH solo para los que cambiaron de
/// posición (skip de no-ops). La UX típica (`ReorderableListView`)
/// reconstruye este array al soltar el drag.
class FlowStepsReorderRequested extends FlowStepsEvent {
  const FlowStepsReorderRequested(this.ids);

  final List<String> ids;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowStepsReorderRequested) return false;
    if (other.ids.length != ids.length) return false;
    for (var i = 0; i < ids.length; i++) {
      if (other.ids[i] != ids[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(ids);
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
