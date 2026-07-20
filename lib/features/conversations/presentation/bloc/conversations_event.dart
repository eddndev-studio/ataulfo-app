part of 'conversations_bloc.dart';

sealed class ConversationsEvent {
  const ConversationsEvent();
}

class ConversationsLoadRequested extends ConversationsEvent {
  const ConversationsLoadRequested();
}

class ConversationsRefreshRequested extends ConversationsEvent {
  const ConversationsRefreshRequested();
}

class ConversationsLoadMoreRequested extends ConversationsEvent {
  const ConversationsLoadMoreRequested();
}

class ConversationsSearchChanged extends ConversationsEvent {
  const ConversationsSearchChanged(this.search);
  final String search;
}

class ConversationsStatusChanged extends ConversationsEvent {
  const ConversationsStatusChanged(this.status);
  final InboxStatus status;
}

class ConversationsChannelChanged extends ConversationsEvent {
  const ConversationsChannelChanged(this.botId);
  final String? botId;
}

class ConversationsLabelChanged extends ConversationsEvent {
  const ConversationsLabelChanged(this.labelId);
  final String? labelId;
}

class ConversationsFiltersCleared extends ConversationsEvent {
  const ConversationsFiltersCleared();
}

class ConversationsValidLabelsChanged extends ConversationsEvent {
  const ConversationsValidLabelsChanged(this.labelIds);
  final Set<String> labelIds;
}

class ConversationsValidChannelsChanged extends ConversationsEvent {
  const ConversationsValidChannelsChanged(this.botIds);
  final Set<String> botIds;
}

class _ConversationsSearchApplied extends ConversationsEvent {
  const _ConversationsSearchApplied(this.search);
  final String search;
}

class _ConversationsCacheChanged extends ConversationsEvent {
  const _ConversationsCacheChanged(this.items);
  final List<Conversation> items;
}

class _ConversationsCacheFailed extends ConversationsEvent {
  const _ConversationsCacheFailed(this.error);
  final Object error;
}

class _ConversationsLiveArrived extends ConversationsEvent {
  const _ConversationsLiveArrived(this.event);
  final InboxLiveEvent event;
}

class _ConversationsLiveRefreshRequested extends ConversationsEvent {
  const _ConversationsLiveRefreshRequested();
}
