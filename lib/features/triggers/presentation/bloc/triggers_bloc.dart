import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/trigger.dart';
import '../../domain/failures/triggers_failure.dart';
import '../../domain/repositories/triggers_repository.dart';

/// Bloc del listado de triggers de una Template (S11). Vida atada al
/// `TemplateDetailPage`: se construye con el templateId y arranca en
/// `Loading` para no flashear Initial. Sin mutaciones — el slice
/// read-only sólo lista; F8 extiende con create/update/delete.
///
/// Separado del FlowsBloc y del TemplateDetailBloc: cada sección de la
/// página gestiona su propio failure sin ocultar las demás. Un 403 en
/// triggers no oculta los flows; un 503 cargando triggers no oculta el
/// detalle de la plantilla.
class TriggersBloc extends Bloc<TriggersEvent, TriggersState> {
  TriggersBloc({required TriggersRepository repo, required String templateId})
    : _repo = repo,
      _templateId = templateId,
      super(const TriggersLoading()) {
    on<TriggersLoadRequested>(_onLoad);
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
