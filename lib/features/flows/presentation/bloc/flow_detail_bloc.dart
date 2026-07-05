import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/flow.dart';
import '../../domain/failures/flows_failure.dart';
import '../../domain/repositories/flows_repository.dart';

part 'flow_detail_event.dart';
part 'flow_detail_state.dart';

/// Bloc del detalle de un flow (S11). Vida atada a la ruta `/flows/:id`:
/// se construye con el id y arranca en `Loading` para no flashear
/// Initial.
///
/// Sostiene la cabecera del flow + la lista de "siblings" (otros flows
/// de la misma Template) que el tab de configuración necesita para el
/// multi-select de `excludesFlows`. Cargar siblings aquí evita un
/// segundo bloc por SettingsTab y centraliza el lifecycle (mismos
/// repo, misma org-scope, mismo retry).
///
/// El refetch tras una mutación trae cabecera + siblings: la cabecera
/// porque `version` incrementa, los siblings porque otro operador pudo
/// añadir / pausar / borrar uno entre el load inicial y el save.
class FlowDetailBloc extends Bloc<FlowDetailEvent, FlowDetailState> {
  FlowDetailBloc({required FlowsRepository repo, required String id})
    : _repo = repo,
      _id = id,
      super(const FlowDetailLoading()) {
    on<FlowDetailLoadRequested>(_onLoad);
    on<FlowDetailRefreshRequested>(_onRefresh);
    on<FlowDetailUpdateSettingsRequested>(_onUpdateSettings);
    on<FlowDetailRenameRequested>(_onRename);
    on<FlowDetailSetActiveRequested>(_onSetActive);
    on<FlowDetailDeleteRequested>(_onDelete);
  }

  final FlowsRepository _repo;
  final String _id;

  /// Snapshot vigente de la cabecera, o `null` cuando el estado no lo
  /// tiene (Loading / Failed / Deleted). Las acciones de cabecera lo
  /// exigen: sin snapshot no hay `version` fiable para el CAS.
  (Flow, List<Flow>, bool)? get _snapshot => switch (state) {
    FlowDetailLoaded(:final flow, :final siblings, :final siblingsFailed) => (
      flow,
      siblings,
      siblingsFailed,
    ),
    FlowDetailMutationFailed(
      :final flow,
      :final siblings,
      :final siblingsFailed,
    ) =>
      (flow, siblings, siblingsFailed),
    _ => null,
  };

  Future<void> _onLoad(
    FlowDetailLoadRequested event,
    Emitter<FlowDetailState> emit,
  ) async {
    if (state is! FlowDetailLoading) {
      emit(const FlowDetailLoading());
    }
    try {
      final flow = await _repo.flowById(_id);
      final (siblings, siblingsFailed) = await _loadSiblings(flow);
      emit(FlowDetailLoaded(flow, siblings, siblingsFailed: siblingsFailed));
    } on FlowsFailure catch (f) {
      emit(FlowDetailFailed(f));
    }
  }

  /// Carga los flows hermanos de la Template y filtra el flow actual.
  /// Degrada graciosamente: si listFlows falla pero la cabecera está
  /// disponible, devolvemos `([], true)` para que la UI muestre el
  /// editor con un aviso en el multi-select en lugar de un error global.
  Future<(List<Flow>, bool)> _loadSiblings(Flow flow) async {
    try {
      final all = await _repo.listFlows(flow.templateId);
      final siblings = <Flow>[
        for (final f in all)
          if (f.id != flow.id) f,
      ];
      return (siblings, false);
    } on FlowsFailure {
      return (const <Flow>[], true);
    }
  }

  /// Refetch de cabecera + siblings conservando el snapshot visible: no
  /// pasa por Loading, así la página no parpadea al volver de una
  /// subpágina que pudo mutar el flujo (la `version` del CAS se
  /// refresca). Best-effort: un fallo deja el estado como estaba — el
  /// snapshot vigente sigue siendo utilizable aunque pueda estar viejo.
  Future<void> _onRefresh(
    FlowDetailRefreshRequested event,
    Emitter<FlowDetailState> emit,
  ) async {
    if (_snapshot == null) return;
    try {
      final flow = await _repo.flowById(_id);
      final (siblings, siblingsFailed) = await _loadSiblings(flow);
      emit(FlowDetailLoaded(flow, siblings, siblingsFailed: siblingsFailed));
    } on FlowsFailure {
      // Silencio deliberado: refresco oportunista, no una carga que el
      // operador pidió — no se le interrumpe con un error.
    }
  }

  Future<void> _onRename(
    FlowDetailRenameRequested event,
    Emitter<FlowDetailState> emit,
  ) => _putHeader(emit, name: event.name);

  Future<void> _onSetActive(
    FlowDetailSetActiveRequested event,
    Emitter<FlowDetailState> emit,
  ) => _putHeader(emit, isActive: event.isActive);

  /// PUT replace-completo de la cabecera con SOLO el campo pedido
  /// cambiado; el resto viaja intacto desde el snapshot (omitir un campo
  /// reaplicaría su default). El Flow que devuelve el backend es la
  /// verdad fresca — `version` ya incrementada — así que no hay refetch:
  /// se emite Loaded con él y los siblings vigentes.
  Future<void> _putHeader(
    Emitter<FlowDetailState> emit, {
    String? name,
    bool? isActive,
  }) async {
    final snap = _snapshot;
    if (snap == null) return;
    final (flow, siblings, siblingsFailed) = snap;
    emit(FlowDetailMutating(flow, siblings, siblingsFailed: siblingsFailed));
    try {
      final updatedFlow = await _repo.updateFlow(
        flowId: flow.id,
        version: flow.version,
        name: name ?? flow.name,
        isActive: isActive ?? flow.isActive,
        aiInvocable: flow.aiInvocable,
        cooldownMs: flow.cooldownMs,
        usageLimit: flow.usageLimit,
        excludesFlows: flow.excludesFlows,
      );
      emit(
        FlowDetailLoaded(updatedFlow, siblings, siblingsFailed: siblingsFailed),
      );
    } on FlowsFailure catch (f) {
      emit(
        FlowDetailMutationFailed(
          flow,
          siblings,
          f,
          siblingsFailed: siblingsFailed,
        ),
      );
    }
  }

  Future<void> _onDelete(
    FlowDetailDeleteRequested event,
    Emitter<FlowDetailState> emit,
  ) async {
    final snap = _snapshot;
    if (snap == null) return;
    final (flow, siblings, siblingsFailed) = snap;
    emit(FlowDetailMutating(flow, siblings, siblingsFailed: siblingsFailed));
    try {
      await _repo.deleteFlow(flow.id);
      emit(const FlowDetailDeleted());
    } on FlowsFailure catch (f) {
      emit(
        FlowDetailMutationFailed(
          flow,
          siblings,
          f,
          siblingsFailed: siblingsFailed,
        ),
      );
    }
  }

  Future<void> _onUpdateSettings(
    FlowDetailUpdateSettingsRequested event,
    Emitter<FlowDetailState> emit,
  ) async {
    final current = state;
    final Flow snapshot;
    final List<Flow> siblings;
    final bool siblingsFailed;
    if (current is FlowDetailLoaded) {
      snapshot = current.flow;
      siblings = current.siblings;
      siblingsFailed = current.siblingsFailed;
    } else if (current is FlowDetailMutationFailed) {
      snapshot = current.flow;
      siblings = current.siblings;
      siblingsFailed = current.siblingsFailed;
    } else {
      // Desde Loading/Failed/Saving no hay snapshot fiable.
      return;
    }

    emit(
      FlowDetailMutating(snapshot, siblings, siblingsFailed: siblingsFailed),
    );
    try {
      // PUT replace-completo: name/isActive viajan tal como están en
      // el snapshot porque la Settings tab no los edita pero el body
      // los requiere.
      await _repo.updateFlow(
        flowId: snapshot.id,
        version: snapshot.version,
        name: snapshot.name,
        isActive: snapshot.isActive,
        aiInvocable: event.aiInvocable,
        cooldownMs: event.cooldownMs,
        usageLimit: event.usageLimit,
        excludesFlows: event.excludesFlows,
      );
    } on FlowsFailure catch (f) {
      emit(
        FlowDetailMutationFailed(
          snapshot,
          siblings,
          f,
          siblingsFailed: siblingsFailed,
        ),
      );
      return;
    }
    emit(const FlowDetailLoading());
    try {
      final flow = await _repo.flowById(_id);
      final (newSiblings, newSiblingsFailed) = await _loadSiblings(flow);
      emit(
        FlowDetailLoaded(flow, newSiblings, siblingsFailed: newSiblingsFailed),
      );
    } on FlowsFailure catch (f) {
      // El refetch falló: la mutación SÍ persistió pero no tenemos
      // verdad fresca. Caer a Failed global, no a SaveFailed (el
      // snapshot ya está obsoleto).
      emit(FlowDetailFailed(f));
    }
  }
}
