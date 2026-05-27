import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/flow.dart';
import '../../domain/failures/flows_failure.dart';
import '../../domain/repositories/flows_repository.dart';

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
    on<FlowDetailUpdateSettingsRequested>(_onUpdateSettings);
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
      final (siblings, siblingsFailed) = await _loadSiblings(flow);
      emit(
        FlowDetailLoaded(flow, siblings, siblingsFailed: siblingsFailed),
      );
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
    } else if (current is FlowDetailSettingsSaveFailed) {
      snapshot = current.flow;
      siblings = current.siblings;
      siblingsFailed = current.siblingsFailed;
    } else {
      // Desde Loading/Failed/Saving no hay snapshot fiable.
      return;
    }

    emit(
      FlowDetailSettingsSaving(
        snapshot,
        siblings,
        siblingsFailed: siblingsFailed,
      ),
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
        cooldownMs: event.cooldownMs,
        usageLimit: event.usageLimit,
        excludesFlows: event.excludesFlows,
      );
    } on FlowsFailure catch (f) {
      emit(
        FlowDetailSettingsSaveFailed(
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
        FlowDetailLoaded(
          flow,
          newSiblings,
          siblingsFailed: newSiblingsFailed,
        ),
      );
    } on FlowsFailure catch (f) {
      // El refetch falló: la mutación SÍ persistió pero no tenemos
      // verdad fresca. Caer a Failed global, no a SaveFailed (el
      // snapshot ya está obsoleto).
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

/// Pide guardar los gates del flow (cooldown / usage limit / exclusiones).
/// `name` e `isActive` no viajan: el bloc los toma del snapshot Loaded
/// y los reenvía intactos en el PUT replace-completo. La version del
/// CAS también sale del snapshot.
class FlowDetailUpdateSettingsRequested extends FlowDetailEvent {
  const FlowDetailUpdateSettingsRequested({
    required this.cooldownMs,
    required this.usageLimit,
    required this.excludesFlows,
  });

  final int cooldownMs;
  final int usageLimit;
  final List<String> excludesFlows;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowDetailUpdateSettingsRequested) return false;
    if (other.cooldownMs != cooldownMs || other.usageLimit != usageLimit) {
      return false;
    }
    if (other.excludesFlows.length != excludesFlows.length) return false;
    for (var i = 0; i < excludesFlows.length; i++) {
      if (other.excludesFlows[i] != excludesFlows[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(cooldownMs, usageLimit, Object.hashAll(excludesFlows));
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
  const FlowDetailLoaded(
    this.flow,
    this.siblings, {
    required this.siblingsFailed,
  });

  final Flow flow;
  final List<Flow> siblings;

  /// `true` ⇒ siblings está vacío porque listFlows falló (no porque
  /// no haya otros flujos). La UI lo usa para mostrar un aviso "no
  /// pudimos cargar otros flujos" sin tirar la página.
  final bool siblingsFailed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowDetailLoaded) return false;
    if (other.flow != flow || other.siblingsFailed != siblingsFailed) {
      return false;
    }
    if (other.siblings.length != siblings.length) return false;
    for (var i = 0; i < siblings.length; i++) {
      if (other.siblings[i] != siblings[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(flow, siblingsFailed, Object.hashAll(siblings));
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

/// Mutación de gates en vuelo. Preserva el snapshot anterior para que
/// la UI siga mostrando los valores actuales mientras dibuja un
/// indicador de progreso. Mismo trío de campos que `Loaded` para que
/// el sheet pueda renderizar igual.
class FlowDetailSettingsSaving extends FlowDetailState {
  const FlowDetailSettingsSaving(
    this.flow,
    this.siblings, {
    required this.siblingsFailed,
  });

  final Flow flow;
  final List<Flow> siblings;
  final bool siblingsFailed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowDetailSettingsSaving) return false;
    if (other.flow != flow || other.siblingsFailed != siblingsFailed) {
      return false;
    }
    if (other.siblings.length != siblings.length) return false;
    for (var i = 0; i < siblings.length; i++) {
      if (other.siblings[i] != siblings[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(flow, siblingsFailed, Object.hashAll(siblings));
}

/// La mutación de gates falló pero el snapshot anterior sigue
/// intacto. El editor muestra el failure (Conflict ⇒ "recarga",
/// InvalidSettings ⇒ "revisa cooldown / límite") sin perder el
/// estado del form.
class FlowDetailSettingsSaveFailed extends FlowDetailState {
  const FlowDetailSettingsSaveFailed(
    this.flow,
    this.siblings,
    this.failure, {
    required this.siblingsFailed,
  });

  final Flow flow;
  final List<Flow> siblings;
  final FlowsFailure failure;
  final bool siblingsFailed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowDetailSettingsSaveFailed) return false;
    if (other.flow != flow ||
        other.failure != failure ||
        other.siblingsFailed != siblingsFailed) {
      return false;
    }
    if (other.siblings.length != siblings.length) return false;
    for (var i = 0; i < siblings.length; i++) {
      if (other.siblings[i] != siblings[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(flow, failure, siblingsFailed, Object.hashAll(siblings));
}
