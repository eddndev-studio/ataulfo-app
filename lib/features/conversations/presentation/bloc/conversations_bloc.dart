import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/conversation.dart';
import '../../domain/failures/conversations_failure.dart';
import '../../domain/repositories/conversations_repository.dart';

/// Bloc del listado de conversaciones de un bot (S07 RF#7). DB-as-source: el
/// bloc **observa** `repo.watchForBot` (la DB local) y dispara `repo.refresh`
/// para el write-through HTTP. `isRefreshing` deja que el pull-to-refresh no
/// oculte la lista. Offline, el watch sigue sirviendo la caché: un refresh
/// fallido con caché no escondida no degrada a error.
class ConversationsBloc extends Bloc<ConversationsEvent, ConversationsState> {
  ConversationsBloc({
    required ConversationsRepository repo,
    required String botId,
  }) : _repo = repo,
       _botId = botId,
       super(const ConversationsInitial()) {
    on<ConversationsLoadRequested>(_onLoad);
    on<ConversationsRefreshRequested>(_onRefresh);
    on<_ConversationsDbEmitted>(_onDbEmitted);
    on<_ConversationsWatchFailed>(_onWatchFailed);
  }

  final ConversationsRepository _repo;
  final String _botId;

  StreamSubscription<List<Conversation>>? _sub;
  List<Conversation>? _items;
  bool _refreshing = false;

  /// El bot al que pertenece esta bandeja. Lo usa la fila para navegar al hilo
  /// (`/bots/:id/sessions/:chatLid`) sin recibir el id por separado.
  String get botId => _botId;

  Future<void> _onLoad(
    ConversationsLoadRequested event,
    Emitter<ConversationsState> emit,
  ) async {
    if (_items == null) emit(const ConversationsLoading());
    // Una sola suscripción al watch; los reintentos solo re-disparan el refresh.
    _sub ??= _repo
        .watchForBot(_botId)
        .listen(
          (items) => add(_ConversationsDbEmitted(items)),
          onError: (Object e) {
            if (e is ConversationsFailure) add(_ConversationsWatchFailed(e));
          },
        );
    add(const ConversationsRefreshRequested());
  }

  void _onDbEmitted(
    _ConversationsDbEmitted event,
    Emitter<ConversationsState> emit,
  ) {
    _items = event.items;
    emit(ConversationsLoaded(items: event.items, isRefreshing: _refreshing));
  }

  void _onWatchFailed(
    _ConversationsWatchFailed event,
    Emitter<ConversationsState> emit,
  ) {
    // Con caché se mantiene lo último visto; sin ella, el error del watch sí
    // sube a la UI para ofrecer reintentar.
    final cached = _items;
    if (cached == null || cached.isEmpty) {
      emit(ConversationsFailed(event.failure));
    }
  }

  Future<void> _onRefresh(
    ConversationsRefreshRequested event,
    Emitter<ConversationsState> emit,
  ) async {
    _refreshing = true;
    final before = _items;
    if (before != null) {
      emit(ConversationsLoaded(items: before, isRefreshing: true));
    }
    try {
      await _repo.refresh(_botId);
      _refreshing = false;
      final after = _items;
      if (after != null) {
        emit(ConversationsLoaded(items: after, isRefreshing: false));
      }
    } on ConversationsFailure catch (f) {
      _refreshing = false;
      final cached = _items;
      if (cached != null && cached.isNotEmpty) {
        // Fallo de red con caché: offline-first sirve lo último visto.
        emit(ConversationsLoaded(items: cached, isRefreshing: false));
      } else {
        emit(ConversationsFailed(f));
      }
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
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

/// Interno: nueva emisión del watch de la DB. Lleva la lista ya mapeada.
class _ConversationsDbEmitted extends ConversationsEvent {
  const _ConversationsDbEmitted(this.items);
  final List<Conversation> items;
}

/// Interno: el watch de la DB emitió un error (ya tipado por el repo).
class _ConversationsWatchFailed extends ConversationsEvent {
  const _ConversationsWatchFailed(this.failure);
  final ConversationsFailure failure;
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
