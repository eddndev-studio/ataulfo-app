part of 'conversations_bloc.dart';

enum ConversationsPhase { initial, loading, ready, failure }

const Object _stateNotProvided = Object();

class ConversationsState {
  const ConversationsState({
    this.query = const InboxQuery(),
    this.phase = ConversationsPhase.initial,
    this.items = const <Conversation>[],
    this.nextCursor,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isOffline = false,
    this.failure,
  });

  final InboxQuery query;
  final ConversationsPhase phase;
  final List<Conversation> items;
  final String? nextCursor;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isOffline;
  final ConversationsFailure? failure;

  bool get hasMore => nextCursor != null;

  ConversationsState copyWith({
    InboxQuery? query,
    ConversationsPhase? phase,
    List<Conversation>? items,
    Object? nextCursor = _stateNotProvided,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isOffline,
    Object? failure = _stateNotProvided,
  }) => ConversationsState(
    query: query ?? this.query,
    phase: phase ?? this.phase,
    items: items ?? this.items,
    nextCursor: identical(nextCursor, _stateNotProvided)
        ? this.nextCursor
        : nextCursor as String?,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isOffline: isOffline ?? this.isOffline,
    failure: identical(failure, _stateNotProvided)
        ? this.failure
        : failure as ConversationsFailure?,
  );

  @override
  bool operator ==(Object other) =>
      other is ConversationsState &&
      other.query == query &&
      other.phase == phase &&
      _conversationListsEqual(other.items, items) &&
      other.nextCursor == nextCursor &&
      other.isRefreshing == isRefreshing &&
      other.isLoadingMore == isLoadingMore &&
      other.isOffline == isOffline &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(
    query,
    phase,
    Object.hashAll(items),
    nextCursor,
    isRefreshing,
    isLoadingMore,
    isOffline,
    failure,
  );
}

bool _conversationListsEqual(List<Conversation> a, List<Conversation> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
