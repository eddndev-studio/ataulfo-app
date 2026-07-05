import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/step.dart' as fdom;
import '../../domain/failures/flows_failure.dart';
import '../../domain/repositories/flows_repository.dart';

part 'flow_steps_event.dart';
part 'flow_steps_state.dart';

/// Bloc de la lista de Steps de un Flow (S11). Vive en el tab "Pasos"
/// del editor; vida atada a la ruta `/flows/:id`. Arranca en `Loading`
/// para no flashear Initial.
///
/// Separado del `FlowDetailBloc` (que sostiene la cabecera del flow)
/// porque las mutaciones de steps (add / edit / delete / reorder) viven
/// solo en este tab — mantenerlas en el bloc del page mezclaría
/// responsabilidades de tres tabs independientes.
///
/// Patrón de mutación: cada Add/Update/Delete/Reorder sigue
/// Mutating(snapshot) → éxito ⇒ Refreshing(snapshot) + refetch +
/// Loaded(refrescado); failure ⇒ MutationFailed(snapshot, failure) para
/// que la UI muestre el error sin tirar la lista actual. El refetch corre
/// SIEMPRE con la lista visible — nunca vuelve a Loading, que sustituiría
/// las cards por un spinner y perdería el scroll del operador. A
/// diferencia de var-defs, no hay CAS — los endpoints de step no exponen
/// version del flow padre.
class FlowStepsBloc extends Bloc<FlowStepsEvent, FlowStepsState> {
  FlowStepsBloc({required FlowsRepository repo, required String flowId})
    : _repo = repo,
      _flowId = flowId,
      super(const FlowStepsLoading()) {
    on<FlowStepsLoadRequested>(_onLoad);
    on<FlowStepsRefreshRequested>(_onRefresh);
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

  /// Refetch conservando la lista visible: emite Refreshing(snapshot) en
  /// vez de Loading, así el operador nunca ve las cards sustituidas por
  /// un spinner. Es el retry de un RefreshFailed; sin snapshot vigente no
  /// hay nada que conservar (ese caso es LoadRequested).
  Future<void> _onRefresh(
    FlowStepsRefreshRequested event,
    Emitter<FlowStepsState> emit,
  ) async {
    final snapshot = _visibleSteps(state);
    if (snapshot == null) return;
    emit(FlowStepsRefreshing(snapshot));
    try {
      final steps = await _repo.listSteps(_flowId);
      emit(FlowStepsLoaded(steps));
    } on FlowsFailure catch (f) {
      emit(FlowStepsRefreshFailed(snapshot, f));
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
        // `order` explícito = POSICIÓN DE INSERCIÓN (el backend desplaza
        // los steps siguientes). Sin él, append clásico al final. Lo usa
        // el condicional: debe insertarse ANTES de sus destinos o el
        // backend rechaza el create con 422 (forward-only).
        order: event.order ?? snapshot.length,
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

  /// Reorder ATÓMICO: una sola llamada con el array completo de ids; el
  /// backend renumera 0..n-1 en una transacción y valida que ningún
  /// condicional quede después de sus destinos. Los destinos de los CT
  /// son refs por id, así que reordenar no exige remap alguno — el viejo
  /// remapper posicional del cliente murió con ese shape.
  ///
  /// OPTIMISTA: el snapshot visible adopta el orden nuevo (renumerado
  /// 0..n-1, como hará el backend) desde el primer emit — el item se
  /// queda donde el operador lo soltó, sin rebotar a su posición previa.
  /// Un rechazo revierte al orden anterior vía MutationFailed (atómico:
  /// el backend quedó EXACTAMENTE como estaba, sin refetch).
  ///
  /// Si todos los ids ya están en su posición, no pasa nada (la UX
  /// dispara reorder con el array entero aunque el operador haya soltado
  /// el item en su lugar original): ni request, ni cambio de estado.
  Future<void> _onReorder(
    FlowStepsReorderRequested event,
    Emitter<FlowStepsState> emit,
  ) async {
    final snapshot = _visibleSteps(state);
    if (snapshot == null) return;
    final reordered = _applyOrder(snapshot, event.ids);
    if (reordered == null) return;
    await _runMutation(emit, (_) async {
      await _repo.reorderSteps(flowId: _flowId, ids: event.ids);
    }, optimistic: reordered);
  }

  /// Snapshot en el orden de `ids`, renumerado 0..n-1 (el mismo resultado
  /// que producirá el backend). null cuando no hay nada que aplicar: los
  /// ids ya están en ese orden, o no mapean 1:1 contra el snapshot (lista
  /// desincronizada — mejor no inventar un orden).
  static List<fdom.Step>? _applyOrder(
    List<fdom.Step> snapshot,
    List<String> ids,
  ) {
    if (ids.length != snapshot.length) return null;
    var changed = false;
    final byId = <String, fdom.Step>{for (final s in snapshot) s.id: s};
    final out = <fdom.Step>[];
    for (var i = 0; i < ids.length; i++) {
      final s = byId[ids[i]];
      if (s == null) return null;
      if (snapshot[i].id != ids[i]) changed = true;
      out.add(s.copyWith(order: i));
    }
    return changed ? out : null;
  }

  /// Lista visible del estado vigente, o null si el estado no la tiene
  /// (Loading/Failed iniciales, o Mutating/Refreshing con un request ya
  /// en vuelo — la UI gatea, esto es la red de seguridad).
  static List<fdom.Step>? _visibleSteps(FlowStepsState s) => switch (s) {
    FlowStepsLoaded(steps: final st) => st,
    FlowStepsMutationFailed(steps: final st) => st,
    FlowStepsRefreshFailed(steps: final st) => st,
    _ => null,
  };

  /// Orquesta una mutación de step:
  /// 1. lee el snapshot visible (Loaded, MutationFailed o RefreshFailed) —
  ///    desde Loading/Failed/Mutating/Refreshing ignora silenciosamente,
  /// 2. emit Mutating(visible) — `optimistic`, si viene, reemplaza al
  ///    snapshot como lista visible (reorder ya asentado),
  /// 3. corre `mutate(snapshot)` — failure ⇒ MutationFailed(snapshot, f):
  ///    la lista revierte al estado PREVIO al optimismo,
  /// 4. emit Refreshing(visible) + refetch — failure del refetch ⇒
  ///    RefreshFailed(visible, f): la mutación SÍ fue persistida, así que
  ///    la lista visible se conserva y la UI ofrece reintentar el listado.
  Future<void> _runMutation(
    Emitter<FlowStepsState> emit,
    Future<void> Function(List<fdom.Step> snapshot) mutate, {
    List<fdom.Step>? optimistic,
  }) async {
    final snapshot = _visibleSteps(state);
    if (snapshot == null) return;
    final visible = optimistic ?? snapshot;

    emit(FlowStepsMutating(visible));
    try {
      await mutate(snapshot);
    } on FlowsFailure catch (f) {
      emit(FlowStepsMutationFailed(snapshot, f));
      return;
    }
    emit(FlowStepsRefreshing(visible));
    try {
      final steps = await _repo.listSteps(_flowId);
      emit(FlowStepsLoaded(steps));
    } on FlowsFailure catch (f) {
      emit(FlowStepsRefreshFailed(visible, f));
    }
  }
}
