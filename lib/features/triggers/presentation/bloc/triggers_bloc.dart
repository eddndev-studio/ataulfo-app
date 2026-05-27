import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/trigger.dart';
import '../../domain/failures/triggers_failure.dart';
import '../../domain/repositories/triggers_repository.dart';

/// Bloc del listado de triggers de una Template (S11). Vida atada al
/// `TemplateDetailPage`: se construye con el templateId y arranca en
/// `Loading` para no flashear Initial.
///
/// Separado del FlowsBloc y del TemplateDetailBloc: cada sección de la
/// página gestiona su propio failure sin ocultar las demás. Un 403 en
/// triggers no oculta los flows; un 503 cargando triggers no oculta el
/// detalle de la plantilla.
///
/// Patrón de mutación (espejo del FlowStepsBloc): cada Add/Update/Delete
/// sigue `Mutating(snapshot)` → éxito ⇒ `Loading` + refetch + `Loaded`;
/// failure ⇒ `MutationFailed(snapshot, failure)` para que la UI muestre
/// el error sin tirar la lista actual. Sin CAS — el contrato de Trigger
/// no expone version.
class TriggersBloc extends Bloc<TriggersEvent, TriggersState> {
  TriggersBloc({required TriggersRepository repo, required String templateId})
    : _repo = repo,
      _templateId = templateId,
      super(const TriggersLoading()) {
    on<TriggersLoadRequested>(_onLoad);
    on<TriggersAddRequested>(_onAdd);
    on<TriggersUpdateRequested>(_onUpdate);
    on<TriggersDeleteRequested>(_onDelete);
  }

  final TriggersRepository _repo;
  final String _templateId;

  Future<void> _onLoad(
    TriggersLoadRequested event,
    Emitter<TriggersState> emit,
  ) async {
    if (state is! TriggersLoading) {
      emit(const TriggersLoading());
    }
    try {
      final triggers = await _repo.listTriggers(_templateId);
      emit(TriggersLoaded(triggers));
    } on TriggersFailure catch (f) {
      emit(TriggersFailed(f));
    }
  }

  Future<void> _onAdd(
    TriggersAddRequested event,
    Emitter<TriggersState> emit,
  ) async {
    await _runMutation(emit, (_) async {
      await _repo.createTrigger(
        templateId: _templateId,
        flowId: event.flowId,
        triggerType: event.triggerType,
        matchType: event.matchType,
        keyword: event.keyword,
        labelId: event.labelId,
        labelAction: event.labelAction,
        scope: event.scope,
        isActive: event.isActive,
      );
    });
  }

  Future<void> _onUpdate(
    TriggersUpdateRequested event,
    Emitter<TriggersState> emit,
  ) async {
    await _runMutation(emit, (_) async {
      await _repo.updateTrigger(
        triggerId: event.triggerId,
        triggerType: event.triggerType,
        matchType: event.matchType,
        keyword: event.keyword,
        labelId: event.labelId,
        labelAction: event.labelAction,
        scope: event.scope,
        isActive: event.isActive,
      );
    });
  }

  Future<void> _onDelete(
    TriggersDeleteRequested event,
    Emitter<TriggersState> emit,
  ) async {
    await _runMutation(emit, (_) async {
      await _repo.deleteTrigger(event.triggerId);
    });
  }

  /// Orquesta una mutación de trigger. Reusa el snapshot del último
  /// estado válido (`Loaded` o `MutationFailed`); desde `Loading`/
  /// `Failed`/`Mutating` ignora — no hay snapshot fiable que preservar.
  Future<void> _runMutation(
    Emitter<TriggersState> emit,
    Future<void> Function(List<Trigger> snapshot) mutate,
  ) async {
    final current = state;
    final List<Trigger> snapshot;
    if (current is TriggersLoaded) {
      snapshot = current.triggers;
    } else if (current is TriggersMutationFailed) {
      snapshot = current.triggers;
    } else {
      return;
    }

    emit(TriggersMutating(snapshot));
    try {
      await mutate(snapshot);
    } on TriggersFailure catch (f) {
      emit(TriggersMutationFailed(snapshot, f));
      return;
    }
    emit(const TriggersLoading());
    try {
      final triggers = await _repo.listTriggers(_templateId);
      emit(TriggersLoaded(triggers));
    } on TriggersFailure catch (f) {
      // El refetch post-éxito falló: el snapshot ya está obsoleto (la
      // mutación SÍ fue persistida). Caer a `Failed` global, no a
      // `MutationFailed`, porque el snapshot no refleja la nueva verdad.
      emit(TriggersFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class TriggersEvent {
  const TriggersEvent();
}

class TriggersLoadRequested extends TriggersEvent {
  const TriggersLoadRequested();
  @override
  bool operator ==(Object other) => other is TriggersLoadRequested;
  @override
  int get hashCode => (TriggersLoadRequested).hashCode;
}

/// Pide crear un trigger en la Template. El body discrimina por
/// `triggerType`: TEXT lleva `matchType + keyword`; LABEL lleva
/// `labelId + labelAction`. El bloc no valida el shape — el sheet
/// es responsable de no despachar combinaciones imposibles; el
/// backend re-valida y emite 422 si algo escapó.
class TriggersAddRequested extends TriggersEvent {
  const TriggersAddRequested({
    required this.flowId,
    required this.triggerType,
    required this.matchType,
    required this.keyword,
    required this.labelId,
    required this.labelAction,
    required this.scope,
    required this.isActive,
  });

  final String flowId;
  final TriggerType triggerType;
  final MatchType? matchType;
  final String keyword;
  final String labelId;
  final LabelAction? labelAction;
  final TriggerScope scope;
  final bool isActive;

  @override
  bool operator ==(Object other) =>
      other is TriggersAddRequested &&
      other.flowId == flowId &&
      other.triggerType == triggerType &&
      other.matchType == matchType &&
      other.keyword == keyword &&
      other.labelId == labelId &&
      other.labelAction == labelAction &&
      other.scope == scope &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(
    flowId,
    triggerType,
    matchType,
    keyword,
    labelId,
    labelAction,
    scope,
    isActive,
  );
}

/// Pide editar un trigger por id. PUT replace-completo: el sheet
/// SIEMPRE envía el documento completo aunque algo no haya cambiado —
/// omitir un campo del wire reaplica su default (isActive=true,
/// scope=BOTH), lo que reactivaría/reescoperia el trigger sin querer.
class TriggersUpdateRequested extends TriggersEvent {
  const TriggersUpdateRequested({
    required this.triggerId,
    required this.triggerType,
    required this.matchType,
    required this.keyword,
    required this.labelId,
    required this.labelAction,
    required this.scope,
    required this.isActive,
  });

  final String triggerId;
  final TriggerType triggerType;
  final MatchType? matchType;
  final String keyword;
  final String labelId;
  final LabelAction? labelAction;
  final TriggerScope scope;
  final bool isActive;

  @override
  bool operator ==(Object other) =>
      other is TriggersUpdateRequested &&
      other.triggerId == triggerId &&
      other.triggerType == triggerType &&
      other.matchType == matchType &&
      other.keyword == keyword &&
      other.labelId == labelId &&
      other.labelAction == labelAction &&
      other.scope == scope &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(
    triggerId,
    triggerType,
    matchType,
    keyword,
    labelId,
    labelAction,
    scope,
    isActive,
  );
}

class TriggersDeleteRequested extends TriggersEvent {
  const TriggersDeleteRequested({required this.triggerId});

  final String triggerId;

  @override
  bool operator ==(Object other) =>
      other is TriggersDeleteRequested && other.triggerId == triggerId;

  @override
  int get hashCode => triggerId.hashCode;
}

// States --------------------------------------------------------------------

sealed class TriggersState {
  const TriggersState();
}

class TriggersLoading extends TriggersState {
  const TriggersLoading();
  @override
  bool operator ==(Object other) => other is TriggersLoading;
  @override
  int get hashCode => (TriggersLoading).hashCode;
}

class TriggersLoaded extends TriggersState {
  const TriggersLoaded(this.triggers);

  final List<Trigger> triggers;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TriggersLoaded) return false;
    if (other.triggers.length != triggers.length) return false;
    for (var i = 0; i < triggers.length; i++) {
      if (other.triggers[i] != triggers[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(triggers);
}

class TriggersFailed extends TriggersState {
  const TriggersFailed(this.failure);

  final TriggersFailure failure;

  @override
  bool operator ==(Object other) =>
      other is TriggersFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

/// Estado durante una mutación en vuelo. Lleva el snapshot vigente
/// para que la UI siga mostrando la lista mientras dibuja un spinner
/// sutil; al terminar pasa a `Loading` (refetch) o a
/// `MutationFailed(snapshot, failure)` (preserva la lista + propaga
/// el error al sheet).
class TriggersMutating extends TriggersState {
  const TriggersMutating(this.triggers);

  final List<Trigger> triggers;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TriggersMutating) return false;
    if (other.triggers.length != triggers.length) return false;
    for (var i = 0; i < triggers.length; i++) {
      if (other.triggers[i] != triggers[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(triggers);
}

/// Estado terminal de una mutación fallida que preserva el snapshot
/// pre-mutación. El sheet abierto interpreta el failure (Invalid /
/// NotFound / Network / etc.) y lo muestra; el resto de la página
/// sigue viendo la lista anterior. Una mutación nueva desde aquí
/// reusa el snapshot como base.
class TriggersMutationFailed extends TriggersState {
  const TriggersMutationFailed(this.triggers, this.failure);

  final List<Trigger> triggers;
  final TriggersFailure failure;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TriggersMutationFailed) return false;
    if (other.failure != failure) return false;
    if (other.triggers.length != triggers.length) return false;
    for (var i = 0; i < triggers.length; i++) {
      if (other.triggers[i] != triggers[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(failure, Object.hashAll(triggers));
}
