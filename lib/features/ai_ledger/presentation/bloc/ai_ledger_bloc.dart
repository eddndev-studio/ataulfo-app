import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ai_ledger_repository.dart';
import '../../domain/entities/ledger_action.dart';
import '../../domain/failures/ai_ledger_failure.dart';

/// Bloc de la bitácora de acciones (S30). Page-scoped: se construye con
/// botId+chatLid; carga la primera página y acumula hacia atrás con
/// MoreRequested (cursor `nextBefore`). Espejo simplificado de AiLogBloc.
class AiLedgerBloc extends Bloc<AiLedgerEvent, AiLedgerState> {
  AiLedgerBloc({
    required AiLedgerRepository repo,
    required String botId,
    required String chatLid,
  }) : _repo = repo,
       _botId = botId,
       _chatLid = chatLid,
       super(const AiLedgerLoading()) {
    on<AiLedgerLoadRequested>(_onLoad);
    on<AiLedgerMoreRequested>(_onMore);
  }

  final AiLedgerRepository _repo;
  final String _botId;
  final String _chatLid;

  Future<void> _onLoad(
    AiLedgerLoadRequested event,
    Emitter<AiLedgerState> emit,
  ) async {
    if (state is! AiLedgerLoading) {
      emit(const AiLedgerLoading());
    }
    try {
      final page = await _repo.page(botId: _botId, chatLid: _chatLid);
      emit(
        AiLedgerLoaded(
          items: page.items,
          nextBefore: page.nextBefore,
          isLoadingMore: false,
        ),
      );
    } on AiLedgerFailure catch (f) {
      emit(AiLedgerFailed(f));
    }
  }

  Future<void> _onMore(
    AiLedgerMoreRequested event,
    Emitter<AiLedgerState> emit,
  ) async {
    final current = state;
    if (current is! AiLedgerLoaded ||
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
        AiLedgerLoaded(
          items: <LedgerAction>[...current.items, ...page.items],
          nextBefore: page.nextBefore,
          isLoadingMore: false,
        ),
      );
    } on AiLedgerFailure {
      // Cargar-más fallido: conserva lo cargado y apaga el spinner.
      emit(current.copyWith(isLoadingMore: false));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class AiLedgerEvent {
  const AiLedgerEvent();
}

class AiLedgerLoadRequested extends AiLedgerEvent {
  const AiLedgerLoadRequested();
  @override
  bool operator ==(Object other) => other is AiLedgerLoadRequested;
  @override
  int get hashCode => (AiLedgerLoadRequested).hashCode;
}

class AiLedgerMoreRequested extends AiLedgerEvent {
  const AiLedgerMoreRequested();
  @override
  bool operator ==(Object other) => other is AiLedgerMoreRequested;
  @override
  int get hashCode => (AiLedgerMoreRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class AiLedgerState {
  const AiLedgerState();
}

class AiLedgerLoading extends AiLedgerState {
  const AiLedgerLoading();
  @override
  bool operator ==(Object other) => other is AiLedgerLoading;
  @override
  int get hashCode => (AiLedgerLoading).hashCode;
}

class AiLedgerLoaded extends AiLedgerState {
  const AiLedgerLoaded({
    required this.items,
    required this.nextBefore,
    required this.isLoadingMore,
  });

  final List<LedgerAction> items;
  final int? nextBefore;
  final bool isLoadingMore;

  AiLedgerLoaded copyWith({bool? isLoadingMore}) => AiLedgerLoaded(
    items: items,
    nextBefore: nextBefore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AiLedgerLoaded) return false;
    if (other.nextBefore != nextBefore) return false;
    if (other.isLoadingMore != isLoadingMore) return false;
    if (other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i].id != items[i].id) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    nextBefore,
    isLoadingMore,
    Object.hashAll(items.map((e) => e.id)),
  );
}

class AiLedgerFailed extends AiLedgerState {
  const AiLedgerFailed(this.failure);

  final AiLedgerFailure failure;

  @override
  bool operator ==(Object other) =>
      other is AiLedgerFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
