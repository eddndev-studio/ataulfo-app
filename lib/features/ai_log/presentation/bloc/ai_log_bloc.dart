import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ai_log_repository.dart';
import '../../domain/entities/ai_log_entry.dart';
import '../../domain/entities/ai_run_outcome.dart';
import '../../domain/failures/ai_log_failure.dart';

/// Bloc de la vista de observabilidad (ai-log). Page-scoped: se construye
/// con botId+chatLid; carga la primera página y acumula hacia atrás con
/// MoreRequested (cursor `nextBefore`).
class AiLogBloc extends Bloc<AiLogEvent, AiLogState> {
  AiLogBloc({
    required AiLogRepository repo,
    required String botId,
    required String chatLid,
    String? targetExternalId,
    String? targetRunId,
  }) : _repo = repo,
       _botId = botId,
       _chatLid = chatLid,
       _targetExternalId = targetExternalId,
       _targetRunId = targetRunId,
       super(const AiLogLoading()) {
    on<AiLogLoadRequested>(_onLoad);
    on<AiLogMoreRequested>(_onMore);
  }

  final AiLogRepository _repo;
  final String _botId;
  final String _chatLid;

  /// Modo drill-through: si viene un wamid, la vista muestra SOLO la corrida
  /// que produjo ese OUTBOUND (resuelta del log), sin paginar el resto del
  /// historial. Null = vista normal del log de la sesión.
  final String? _targetExternalId;

  /// Modo drill directo (?run=): la corrida YA conocida (badge de la burbuja,
  /// pill de fallo) — sin resolver el wamid. Tiene prioridad sobre el wamid.
  final String? _targetRunId;

  Future<void> _onLoad(
    AiLogLoadRequested event,
    Emitter<AiLogState> emit,
  ) async {
    if (state is! AiLogLoading) {
      emit(const AiLogLoading());
    }
    if (_targetRunId != null) {
      await _loadRun(emit, _targetRunId);
      return;
    }
    if (_targetExternalId != null) {
      await _loadSingleRun(emit, _targetExternalId);
      return;
    }
    try {
      final page = await _repo.page(botId: _botId, chatLid: _chatLid);
      emit(
        AiLogLoaded(
          entries: page.items,
          nextBefore: page.nextBefore,
          isLoadingMore: false,
        ),
      );
    } on AiLogFailure catch (f) {
      emit(AiLogFailed(f));
    }
  }

  /// Resuelve el wamid → corrida y carga solo sus entries. Sin corrida (el
  /// mensaje no salió de la IA) ⇒ Loaded vacío: la vista muestra el aviso, no
  /// un error.
  Future<void> _loadSingleRun(
    Emitter<AiLogState> emit,
    String externalId,
  ) async {
    try {
      final runId = await _repo.runForMessage(
        botId: _botId,
        chatLid: _chatLid,
        externalId: externalId,
      );
      if (runId == null) {
        emit(
          const AiLogLoaded(
            entries: <AiLogEntry>[],
            nextBefore: null,
            isLoadingMore: false,
            drill: true,
          ),
        );
        return;
      }
      await _loadRun(emit, runId);
    } on AiLogFailure catch (f) {
      emit(AiLogFailed(f));
    }
  }

  /// Carga UNA corrida con su desenlace `run{}` (si el wire lo trae). byRun
  /// devuelve ASC; se invierte a DESC porque la vista asume el orden del wire
  /// (más recientes primero).
  Future<void> _loadRun(Emitter<AiLogState> emit, String runId) async {
    try {
      final result = await _repo.byRun(
        botId: _botId,
        chatLid: _chatLid,
        runId: runId,
      );
      emit(
        AiLogLoaded(
          entries: result.items.reversed.toList(growable: false),
          nextBefore: null,
          isLoadingMore: false,
          drill: true,
          run: result.run,
        ),
      );
    } on AiLogFailure catch (f) {
      emit(AiLogFailed(f));
    }
  }

  Future<void> _onMore(
    AiLogMoreRequested event,
    Emitter<AiLogState> emit,
  ) async {
    final current = state;
    if (current is! AiLogLoaded ||
        current.isLoadingMore ||
        current.nextBefore == null) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    try {
      final page = await _repo.page(
        botId: _botId,
        chatLid: _chatLid,
        before: current.nextBefore,
      );
      emit(
        AiLogLoaded(
          entries: <AiLogEntry>[...current.entries, ...page.items],
          nextBefore: page.nextBefore,
          isLoadingMore: false,
        ),
      );
    } on AiLogFailure {
      // Cargar-más fallido: se conserva lo ya cargado y se apaga el
      // spinner; el operador reintenta con el mismo botón.
      emit(current.copyWith(isLoadingMore: false));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class AiLogEvent {
  const AiLogEvent();
}

class AiLogLoadRequested extends AiLogEvent {
  const AiLogLoadRequested();
  @override
  bool operator ==(Object other) => other is AiLogLoadRequested;
  @override
  int get hashCode => (AiLogLoadRequested).hashCode;
}

class AiLogMoreRequested extends AiLogEvent {
  const AiLogMoreRequested();
  @override
  bool operator ==(Object other) => other is AiLogMoreRequested;
  @override
  int get hashCode => (AiLogMoreRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class AiLogState {
  const AiLogState();
}

class AiLogLoading extends AiLogState {
  const AiLogLoading();
  @override
  bool operator ==(Object other) => other is AiLogLoading;
  @override
  int get hashCode => (AiLogLoading).hashCode;
}

class AiLogLoaded extends AiLogState {
  const AiLogLoaded({
    required this.entries,
    required this.nextBefore,
    required this.isLoadingMore,
    this.drill = false,
    this.run,
  });

  /// Stream DESC tal cual el wire (la página agrupa por corrida al pintar).
  final List<AiLogEntry> entries;
  final int? nextBefore;
  final bool isLoadingMore;

  /// Modo drill: la vista pinta UNA corrida como traza (expandida) en vez del
  /// listado del log de la sesión.
  final bool drill;

  /// Desenlace persistido de la corrida del drill (nodo final de la traza), o
  /// null si el wire lo omitió — la vista NO inventa el cierre.
  final AiRunOutcome? run;

  AiLogLoaded copyWith({bool? isLoadingMore}) => AiLogLoaded(
    entries: entries,
    nextBefore: nextBefore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    drill: drill,
    run: run,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AiLogLoaded) return false;
    if (other.nextBefore != nextBefore) return false;
    if (other.isLoadingMore != isLoadingMore) return false;
    if (other.drill != drill) return false;
    if (other.run != run) return false;
    if (other.entries.length != entries.length) return false;
    for (var i = 0; i < entries.length; i++) {
      if (other.entries[i].id != entries[i].id) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    nextBefore,
    isLoadingMore,
    drill,
    run,
    Object.hashAll(entries.map((e) => e.id)),
  );
}

class AiLogFailed extends AiLogState {
  const AiLogFailed(this.failure);

  final AiLogFailure failure;

  @override
  bool operator ==(Object other) =>
      other is AiLogFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
