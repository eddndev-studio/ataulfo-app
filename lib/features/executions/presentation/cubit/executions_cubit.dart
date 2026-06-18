import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../flow_run/domain/repositories/flow_run_repository.dart';
import '../../domain/entities/execution.dart';
import '../../domain/execution_repository.dart';
import '../../domain/failures/execution_failure.dart';

/// Cubit del historial de ejecuciones de un chat. Page-scoped (botId+chatLid).
/// El endpoint per-chat no pagina, así que basta un Cubit con `load()`. Resuelve
/// los nombres de flujo (el wire sólo trae `flowId`) contra la lista de flujos
/// corribles del bot, en best-effort: si falla, la lista igual se muestra con
/// los ids.
class ExecutionsCubit extends Cubit<ExecutionsState> {
  ExecutionsCubit({
    required ExecutionRepository execRepo,
    required FlowRunRepository flowRunRepo,
    required String botId,
    required String chatLid,
  }) : _exec = execRepo,
       _flows = flowRunRepo,
       _botId = botId,
       _chatLid = chatLid,
       super(const ExecutionsLoading());

  final ExecutionRepository _exec;
  final FlowRunRepository _flows;
  final String _botId;
  final String _chatLid;

  Future<void> load() async {
    if (state is! ExecutionsLoading) {
      emit(const ExecutionsLoading());
    }
    final List<Execution> executions;
    try {
      executions = await _exec.listBySession(botId: _botId, chatLid: _chatLid);
    } on ExecutionFailure catch (f) {
      // El cubit es page-scoped: si la pantalla se cerró mientras la petición
      // estaba en vuelo, emitir sobre un controller cerrado lanza StateError en
      // un Future no-aguardado. El load cancelado se descarta.
      if (isClosed) return;
      emit(ExecutionsFailed(f));
      return;
    }
    final names = await _names();
    if (isClosed) return;
    emit(ExecutionsLoaded(executions: executions, flowNames: names));
  }

  /// Mapa flowId→nombre, best-effort: el endpoint sólo lista flujos ACTIVOS, así
  /// que un flujo borrado/inactivo no se resuelve (la vista cae a su id). Un
  /// fallo de red al resolver NO debe tumbar el historial: se degrada a vacío.
  Future<Map<String, String>> _names() async {
    try {
      final runnable = await _flows.listRunnable(_botId);
      return <String, String>{for (final f in runnable) f.id: f.name};
    } on Object {
      return const <String, String>{};
    }
  }
}

sealed class ExecutionsState {
  const ExecutionsState();
}

class ExecutionsLoading extends ExecutionsState {
  const ExecutionsLoading();
  @override
  bool operator ==(Object other) => other is ExecutionsLoading;
  @override
  int get hashCode => (ExecutionsLoading).hashCode;
}

class ExecutionsLoaded extends ExecutionsState {
  const ExecutionsLoaded({required this.executions, required this.flowNames});

  /// Ejecuciones DESC tal cual el wire (más recientes primero).
  final List<Execution> executions;

  /// flowId → nombre legible. Parcial o vacío: la vista cae al id si falta.
  final Map<String, String> flowNames;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ExecutionsLoaded) return false;
    if (other.executions.length != executions.length) return false;
    for (var i = 0; i < executions.length; i++) {
      if (other.executions[i] != executions[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hashAll(executions.map((e) => Object.hash(e.id, e.status)));
}

class ExecutionsFailed extends ExecutionsState {
  const ExecutionsFailed(this.failure);

  final ExecutionFailure failure;

  @override
  bool operator ==(Object other) =>
      other is ExecutionsFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
