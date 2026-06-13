import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ai_log_repository.dart';
import '../../domain/entities/ai_log_entry.dart';
import '../../domain/failures/ai_log_failure.dart';

/// Bloc de la vista de observabilidad (ai-log). Page-scoped: se construye
/// con botId+chatLid; carga la primera página y acumula hacia atrás con
/// MoreRequested (cursor `nextBefore`).
class AiLogBloc extends Bloc<AiLogEvent, AiLogState> {
  AiLogBloc({
    required AiLogRepository repo,
    required String botId,
    required String chatLid,
  }) : _repo = repo,
       _botId = botId,
       _chatLid = chatLid,
       super(const AiLogLoading()) {
    on<AiLogLoadRequested>(_onLoad);
    on<AiLogMoreRequested>(_onMore);
  }

  final AiLogRepository _repo;
  final String _botId;
  final String _chatLid;

  Future<void> _onLoad(
    AiLogLoadRequested event,
    Emitter<AiLogState> emit,
  ) async {
    if (state is! AiLogLoading) {
      emit(const AiLogLoading());
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
  });

  /// Stream DESC tal cual el wire (la página agrupa por corrida al pintar).
  final List<AiLogEntry> entries;
  final int? nextBefore;
  final bool isLoadingMore;

  AiLogLoaded copyWith({bool? isLoadingMore}) => AiLogLoaded(
    entries: entries,
    nextBefore: nextBefore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AiLogLoaded) return false;
    if (other.nextBefore != nextBefore) return false;
    if (other.isLoadingMore != isLoadingMore) return false;
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
