import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/runnable_flow.dart';
import '../../domain/failures/flow_run_failure.dart';
import '../../domain/repositories/flow_run_repository.dart';

/// Cubit del selector de "correr flujo" del chat (S11). `load` trae los flujos
/// corribles del bot (estado de lista); `run` arranca el elegido y DEVUELVE el
/// desenlace (no lo emite como estado) para que la hoja muestre un SnackBar y se
/// cierre — el progreso real de la Execution se observa en el monitor de
/// ejecuciones, no aquí.
class FlowRunCubit extends Cubit<FlowRunState> {
  FlowRunCubit({required FlowRunRepository repo, required String botId})
    : _repo = repo,
      _botId = botId,
      super(const FlowRunInitial());

  final FlowRunRepository _repo;
  final String _botId;

  Future<void> load() async {
    emit(const FlowRunLoading());
    try {
      final flows = await _repo.listRunnable(_botId);
      emit(FlowRunLoaded(flows));
    } on FlowRunFailure catch (f) {
      emit(FlowRunFailed(f));
    }
  }

  /// Arranca `flowId` sobre `chatLid`. Devuelve `RunStarted` (executionId),
  /// `RunBlocked` (gate, con razón) o `RunError` (resto de failures).
  Future<RunOutcome> run({
    required String chatLid,
    required String flowId,
  }) async {
    try {
      final id = await _repo.run(
        botId: _botId,
        chatLid: chatLid,
        flowId: flowId,
      );
      return RunStarted(id);
    } on FlowRunBlockedFailure catch (f) {
      return RunBlocked(f.reason);
    } on FlowRunFailure catch (f) {
      return RunError(f);
    }
  }
}

// States --------------------------------------------------------------------

sealed class FlowRunState {
  const FlowRunState();
}

class FlowRunInitial extends FlowRunState {
  const FlowRunInitial();
  @override
  bool operator ==(Object other) => other is FlowRunInitial;
  @override
  int get hashCode => (FlowRunInitial).hashCode;
}

class FlowRunLoading extends FlowRunState {
  const FlowRunLoading();
  @override
  bool operator ==(Object other) => other is FlowRunLoading;
  @override
  int get hashCode => (FlowRunLoading).hashCode;
}

class FlowRunLoaded extends FlowRunState {
  const FlowRunLoaded(this.flows);

  final List<RunnableFlow> flows;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowRunLoaded) return false;
    if (other.flows.length != flows.length) return false;
    for (var i = 0; i < flows.length; i++) {
      if (other.flows[i] != flows[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(flows);
}

class FlowRunFailed extends FlowRunState {
  const FlowRunFailed(this.failure);

  final FlowRunFailure failure;

  @override
  bool operator ==(Object other) =>
      other is FlowRunFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}

// RunOutcome (desenlace one-shot de `run`) ----------------------------------

sealed class RunOutcome {
  const RunOutcome();
}

/// El flujo arrancó: `executionId` de la Execution creada.
class RunStarted extends RunOutcome {
  const RunStarted(this.executionId);
  final String executionId;
}

/// Un gate bloqueó el arranque (`COOLDOWN` | `LIMIT` | `EXCLUDED`).
class RunBlocked extends RunOutcome {
  const RunBlocked(this.reason);
  final String reason;
}

/// El arranque falló por transporte/estado (pausado, 404, red, …).
class RunError extends RunOutcome {
  const RunError(this.failure);
  final FlowRunFailure failure;
}
