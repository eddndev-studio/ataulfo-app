import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/conversation.dart';
import '../../domain/failures/conversations_failure.dart';
import '../../domain/repositories/conversations_repository.dart';

/// Bloc del listado de conversaciones de un bot (S07 RF#7). Se construye con
/// el `botId` (la ruta `/bots/:id/sessions` lo aporta), como `BotDetailBloc`.
/// `isRefreshing` dentro de `ConversationsLoaded` deja que el pull-to-refresh
/// no oculte la lista mientras se refresca.
class ConversationsBloc extends Bloc<ConversationsEvent, ConversationsState> {
  ConversationsBloc({
    required ConversationsRepository repo,
    required String botId,
  }) : _repo = repo,
       _botId = botId,
       super(const ConversationsInitial()) {
    on<ConversationsLoadRequested>(_onLoad);
    on<ConversationsRefreshRequested>(_onRefresh);
  }

  final ConversationsRepository _repo;
  final String _botId;

  Future<void> _onLoad(
    ConversationsLoadRequested event,
    Emitter<ConversationsState> emit,
  ) async {
    emit(const ConversationsLoading());
    try {
      final items = await _repo.listForBot(_botId);
      emit(ConversationsLoaded(items: items, isRefreshing: false));
    } on ConversationsFailure catch (f) {
      emit(ConversationsFailed(f));
    }
  }

  Future<void> _onRefresh(
    ConversationsRefreshRequested event,
    Emitter<ConversationsState> emit,
  ) async {
    final current = state;
    if (current is! ConversationsLoaded) {
      add(const ConversationsLoadRequested());
      return;
    }
    emit(ConversationsLoaded(items: current.items, isRefreshing: true));
    try {
      final items = await _repo.listForBot(_botId);
      emit(ConversationsLoaded(items: items, isRefreshing: false));
    } on ConversationsFailure catch (f) {
      emit(ConversationsFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class ConversationsEvent {
  const ConversationsEvent();
}

class ConversationsLoadRequested extends ConversationsEvent {
  const ConversationsLoadRequested();
  @override
  bool operator ==(Object other) => other is ConversationsLoadRequested;
  @override
  int get hashCode => (ConversationsLoadRequested).hashCode;
}

class ConversationsRefreshRequested extends ConversationsEvent {
  const ConversationsRefreshRequested();
  @override
  bool operator ==(Object other) => other is ConversationsRefreshRequested;
  @override
  int get hashCode => (ConversationsRefreshRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class ConversationsState {
  const ConversationsState();
}

class ConversationsInitial extends ConversationsState {
  const ConversationsInitial();
  @override
  bool operator ==(Object other) => other is ConversationsInitial;
  @override
  int get hashCode => (ConversationsInitial).hashCode;
}

class ConversationsLoading extends ConversationsState {
  const ConversationsLoading();
  @override
  bool operator ==(Object other) => other is ConversationsLoading;
  @override
  int get hashCode => (ConversationsLoading).hashCode;
}

class ConversationsLoaded extends ConversationsState {
  const ConversationsLoaded({required this.items, required this.isRefreshing});

  final List<Conversation> items;
  final bool isRefreshing;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ConversationsLoaded) return false;
    if (other.isRefreshing != isRefreshing) return false;
    if (other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(items), isRefreshing);
}

class ConversationsFailed extends ConversationsState {
  const ConversationsFailed(this.failure);

  final ConversationsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is ConversationsFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
