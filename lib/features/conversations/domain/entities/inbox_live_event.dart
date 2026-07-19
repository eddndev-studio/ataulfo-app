sealed class InboxLiveEvent {
  const InboxLiveEvent();
}

/// Señal PII-free de que la proyección REST debe reconciliarse. Sólo conserva
/// identidad y metadatos operativos expresamente permitidos por S30.
class InboxInvalidated extends InboxLiveEvent {
  const InboxInvalidated({
    required this.topic,
    required this.botId,
    required this.chatLid,
    this.needsAttention = false,
  });

  final String topic;
  final String botId;
  final String chatLid;
  final bool needsAttention;

  @override
  bool operator ==(Object other) =>
      other is InboxInvalidated &&
      other.topic == topic &&
      other.botId == botId &&
      other.chatLid == chatLid &&
      other.needsAttention == needsAttention;

  @override
  int get hashCode => Object.hash(topic, botId, chatLid, needsAttention);
}

class InboxReconnected extends InboxLiveEvent {
  const InboxReconnected();

  @override
  bool operator ==(Object other) => other is InboxReconnected;

  @override
  int get hashCode => runtimeType.hashCode;
}
