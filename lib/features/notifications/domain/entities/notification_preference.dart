enum NotificationEventType {
  messageInboundNew('message.inbound.new'),
  botDisconnected('bot.disconnected'),
  flowFailed('flow.failed'),
  agentAlert('agent.alert');

  const NotificationEventType(this.wire);
  final String wire;

  static NotificationEventType fromWire(String wire) {
    for (final value in values) {
      if (value.wire == wire) return value;
    }
    throw FormatException('eventType desconocido: $wire');
  }
}

enum NotificationPriority {
  low('low'),
  normal('normal'),
  high('high');

  const NotificationPriority(this.wire);
  final String wire;

  static NotificationPriority fromWire(String wire) {
    for (final value in values) {
      if (value.wire == wire) return value;
    }
    throw FormatException('priority desconocida: $wire');
  }
}

class NotificationBotFilter {
  const NotificationBotFilter({required this.all, this.botIds = const []});

  final bool all;
  final List<String> botIds;

  @override
  bool operator ==(Object other) =>
      other is NotificationBotFilter &&
      other.all == all &&
      _sameStrings(other.botIds, botIds);

  @override
  int get hashCode => Object.hash(all, Object.hashAll(botIds));
}

class NotificationQuietHours {
  const NotificationQuietHours({
    required this.start,
    required this.end,
    required this.timeZone,
  });

  final String start;
  final String end;
  final String timeZone;

  @override
  bool operator ==(Object other) =>
      other is NotificationQuietHours &&
      other.start == start &&
      other.end == end &&
      other.timeZone == timeZone;

  @override
  int get hashCode => Object.hash(start, end, timeZone);
}

class NotificationPreference {
  const NotificationPreference({
    required this.eventType,
    required this.enabled,
    required this.botFilter,
    required this.labelFilter,
    required this.priority,
    this.quietHours,
  });

  final NotificationEventType eventType;
  final bool enabled;
  final NotificationBotFilter botFilter;
  final List<String> labelFilter;
  final NotificationPriority priority;
  final NotificationQuietHours? quietHours;

  NotificationPreference copyWith({
    NotificationEventType? eventType,
    bool? enabled,
    NotificationBotFilter? botFilter,
    List<String>? labelFilter,
    NotificationPriority? priority,
    NotificationQuietHours? quietHours,
  }) => NotificationPreference(
    eventType: eventType ?? this.eventType,
    enabled: enabled ?? this.enabled,
    botFilter: botFilter ?? this.botFilter,
    labelFilter: labelFilter ?? this.labelFilter,
    priority: priority ?? this.priority,
    quietHours: quietHours ?? this.quietHours,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationPreference &&
      other.eventType == eventType &&
      other.enabled == enabled &&
      other.botFilter == botFilter &&
      _sameStrings(other.labelFilter, labelFilter) &&
      other.priority == priority &&
      other.quietHours == quietHours;

  @override
  int get hashCode => Object.hash(
    eventType,
    enabled,
    botFilter,
    Object.hashAll(labelFilter),
    priority,
    quietHours,
  );
}

bool _sameStrings(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
