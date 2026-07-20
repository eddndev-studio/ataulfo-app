import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/conversation.dart';
import '../../domain/entities/inbox_live_event.dart';
import '../../domain/entities/inbox_query.dart';
import '../../domain/failures/conversations_failure.dart';
import '../../domain/repositories/conversations_repository.dart';

part 'conversations_event.dart';
part 'conversations_projection.dart';
part 'conversations_state.dart';

class ConversationsBloc extends Bloc<ConversationsEvent, ConversationsState> {
  ConversationsBloc({
    required ConversationsRepository repo,
    InboxQuery initialQuery = const InboxQuery(),
    Duration searchDebounce = const Duration(milliseconds: 350),
    Duration liveDebounce = const Duration(milliseconds: 300),
  }) : _repo = repo,
       _searchDebounce = searchDebounce,
       _liveDebounce = liveDebounce,
       super(ConversationsState(query: initialQuery.firstPage)) {
    on<ConversationsLoadRequested>(_onLoad);
    on<ConversationsRefreshRequested>(_onRefresh);
    on<ConversationsLoadMoreRequested>(_onLoadMore);
    on<ConversationsSearchChanged>(_onSearchChanged);
    on<ConversationsStatusChanged>(_onStatusChanged);
    on<ConversationsChannelChanged>(_onChannelChanged);
    on<ConversationsLabelChanged>(_onLabelChanged);
    on<ConversationsFiltersCleared>(_onFiltersCleared);
    on<ConversationsValidLabelsChanged>(_onValidLabelsChanged);
    on<ConversationsValidChannelsChanged>(_onValidChannelsChanged);
    on<_ConversationsSearchApplied>(_onSearchApplied);
    on<_ConversationsCacheChanged>(_onCacheChanged);
    on<_ConversationsCacheFailed>(_onCacheFailed);
    on<_ConversationsLiveArrived>(_onLiveArrived);
    on<_ConversationsLiveRefreshRequested>(_onLiveRefreshRequested);
  }

  final ConversationsRepository _repo;
  final Duration _searchDebounce;
  final Duration _liveDebounce;

  StreamSubscription<List<Conversation>>? _cacheSubscription;
  StreamSubscription<InboxLiveEvent>? _liveSubscription;
  Timer? _searchTimer;
  Timer? _liveTimer;

  final _projection = _ConversationsProjection();
  var _accessRevoked = false;
  var _generation = 0;

  Future<void> _onLoad(
    ConversationsLoadRequested event,
    Emitter<ConversationsState> emit,
  ) async {
    _cacheSubscription ??= _repo.watchAll().listen(
      (items) => add(_ConversationsCacheChanged(items)),
      onError: (Object error) => add(_ConversationsCacheFailed(error)),
    );
    _liveSubscription ??= _repo.live().listen(
      (event) => add(_ConversationsLiveArrived(event)),
    );
    if (state.phase == ConversationsPhase.initial) {
      emit(state.copyWith(phase: ConversationsPhase.loading, failure: null));
    }
    add(const ConversationsRefreshRequested());
  }

  Future<void> _onRefresh(
    ConversationsRefreshRequested event,
    Emitter<ConversationsState> emit,
  ) async {
    final query = state.query.firstPage;
    final generation = ++_generation;
    final hasVisible = state.items.isNotEmpty;
    emit(
      state.copyWith(
        query: query,
        phase: hasVisible
            ? ConversationsPhase.ready
            : ConversationsPhase.loading,
        isRefreshing: hasVisible,
        isLoadingMore: false,
        failure: null,
      ),
    );
    try {
      final page = await _repo.fetchPage(query);
      if (generation != _generation || emit.isDone) return;
      _accessRevoked = false;
      _projection.replaceRemote(page.items);
      emit(
        state.copyWith(
          query: query,
          phase: ConversationsPhase.ready,
          items: _projection.visible(query),
          nextCursor: page.nextCursor,
          isRefreshing: false,
          isLoadingMore: false,
          isOffline: false,
          failure: null,
        ),
      );
    } on ConversationsForbiddenFailure catch (failure) {
      if (generation != _generation || emit.isDone) return;
      _accessRevoked = true;
      _projection.revokeAccess();
      try {
        await _repo.clearCached();
      } catch (_) {
        // La UI se purga aunque SQLite falle: un 403 vivo nunca sirve caché.
      }
      if (!emit.isDone) {
        emit(
          state.copyWith(
            phase: ConversationsPhase.failure,
            items: const <Conversation>[],
            nextCursor: null,
            isRefreshing: false,
            isLoadingMore: false,
            isOffline: false,
            failure: failure,
          ),
        );
      }
    } on ConversationsFailure catch (failure) {
      if (generation != _generation || emit.isDone) return;
      final cached = _projection.localVisible(query);
      final offline =
          failure is ConversationsNetworkFailure ||
          failure is ConversationsTimeoutFailure;
      emit(
        state.copyWith(
          phase: cached.isEmpty
              ? ConversationsPhase.failure
              : ConversationsPhase.ready,
          items: cached,
          nextCursor: null,
          isRefreshing: false,
          isLoadingMore: false,
          isOffline: offline && cached.isNotEmpty,
          failure: cached.isEmpty ? failure : (offline ? null : failure),
        ),
      );
    }
  }

  Future<void> _onLoadMore(
    ConversationsLoadMoreRequested event,
    Emitter<ConversationsState> emit,
  ) async {
    final cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore || state.isRefreshing) return;
    final generation = _generation;
    final query = state.query.copyWith(cursor: cursor);
    emit(state.copyWith(isLoadingMore: true, failure: null));
    try {
      final page = await _repo.fetchPage(query);
      if (generation != _generation || emit.isDone) return;
      _projection.appendRemote(page.items);
      emit(
        state.copyWith(
          items: _projection.visible(state.query),
          nextCursor: page.nextCursor,
          isLoadingMore: false,
          isOffline: false,
          failure: null,
        ),
      );
    } on ConversationsInvalidQueryFailure {
      if (generation == _generation) {
        emit(state.copyWith(isLoadingMore: false, nextCursor: null));
        add(const ConversationsRefreshRequested());
      }
    } on ConversationsFailure catch (failure) {
      if (generation != _generation || emit.isDone) return;
      final offline =
          failure is ConversationsNetworkFailure ||
          failure is ConversationsTimeoutFailure;
      emit(
        state.copyWith(
          isLoadingMore: false,
          isOffline: offline,
          failure: offline ? null : failure,
        ),
      );
    }
  }

  void _onSearchChanged(
    ConversationsSearchChanged event,
    Emitter<ConversationsState> emit,
  ) {
    _searchTimer?.cancel();
    _searchTimer = Timer(
      _searchDebounce,
      () => add(_ConversationsSearchApplied(event.search)),
    );
  }

  void _onSearchApplied(
    _ConversationsSearchApplied event,
    Emitter<ConversationsState> emit,
  ) => _changeQuery(state.query.copyWith(search: event.search.trim()), emit);

  void _onStatusChanged(
    ConversationsStatusChanged event,
    Emitter<ConversationsState> emit,
  ) => _changeQuery(state.query.copyWith(status: event.status), emit);

  void _onChannelChanged(
    ConversationsChannelChanged event,
    Emitter<ConversationsState> emit,
  ) => _changeQuery(state.query.copyWith(botId: event.botId), emit);

  void _onLabelChanged(
    ConversationsLabelChanged event,
    Emitter<ConversationsState> emit,
  ) => _changeQuery(state.query.copyWith(labelId: event.labelId), emit);

  void _onFiltersCleared(
    ConversationsFiltersCleared event,
    Emitter<ConversationsState> emit,
  ) {
    _searchTimer?.cancel();
    _changeQuery(InboxQuery(limit: state.query.limit), emit);
  }

  void _onValidLabelsChanged(
    ConversationsValidLabelsChanged event,
    Emitter<ConversationsState> emit,
  ) {
    _projection.setValidLabelIds(event.labelIds);
    final selected = state.query.labelId;
    if (selected != null && !event.labelIds.contains(selected)) {
      _changeQuery(state.query.copyWith(labelId: null), emit);
      return;
    }
    emit(state.copyWith(items: _projection.visible(state.query)));
  }

  void _onValidChannelsChanged(
    ConversationsValidChannelsChanged event,
    Emitter<ConversationsState> emit,
  ) {
    _projection.setValidBotIds(event.botIds);
    final selected = state.query.botId;
    if (selected != null && !event.botIds.contains(selected)) {
      _changeQuery(state.query.copyWith(botId: null), emit);
      return;
    }
    emit(state.copyWith(items: _projection.visible(state.query)));
  }

  void _changeQuery(InboxQuery next, Emitter<ConversationsState> emit) {
    final query = next.firstPage;
    if (query == state.query) return;
    _generation++;
    _projection.clearRemote();
    final local = _projection.localVisible(query);
    emit(
      state.copyWith(
        query: query,
        phase: local.isEmpty
            ? ConversationsPhase.loading
            : ConversationsPhase.ready,
        items: local,
        nextCursor: null,
        isRefreshing: local.isNotEmpty,
        isLoadingMore: false,
        isOffline: false,
        failure: null,
      ),
    );
    add(const ConversationsRefreshRequested());
  }

  void _onCacheChanged(
    _ConversationsCacheChanged event,
    Emitter<ConversationsState> emit,
  ) {
    _projection.replaceCache(event.items);
    if (_accessRevoked) return;
    final items = _projection.visible(state.query);
    final canRevealCache = items.isNotEmpty || _projection.hasAuthority;
    emit(
      state.copyWith(
        phase: canRevealCache ? ConversationsPhase.ready : state.phase,
        items: items,
      ),
    );
  }

  void _onCacheFailed(
    _ConversationsCacheFailed event,
    Emitter<ConversationsState> emit,
  ) {
    if (state.items.isEmpty && state.phase != ConversationsPhase.failure) {
      emit(
        state.copyWith(
          phase: ConversationsPhase.failure,
          failure: const UnknownConversationsFailure(),
        ),
      );
    }
  }

  Future<void> _onLiveArrived(
    _ConversationsLiveArrived event,
    Emitter<ConversationsState> emit,
  ) async {
    final live = event.event;
    if (live is InboxInvalidated && live.needsAttention) {
      try {
        await _repo.markNeedsAttention(live.botId, live.chatLid);
      } catch (_) {
        // Best-effort; el refresh REST de abajo es la autoridad.
      }
    }
    _liveTimer?.cancel();
    _liveTimer = Timer(
      _liveDebounce,
      () => add(const _ConversationsLiveRefreshRequested()),
    );
  }

  void _onLiveRefreshRequested(
    _ConversationsLiveRefreshRequested event,
    Emitter<ConversationsState> emit,
  ) => add(const ConversationsRefreshRequested());

  @override
  Future<void> close() async {
    _searchTimer?.cancel();
    _liveTimer?.cancel();
    await _cacheSubscription?.cancel();
    await _liveSubscription?.cancel();
    return super.close();
  }
}
