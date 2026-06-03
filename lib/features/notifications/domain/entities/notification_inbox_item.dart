import 'notification_preference.dart';

enum NotificationInboxStatus {
  unread('UNREAD'),
  read('READ');

  const NotificationInboxStatus(this.wire);
  final String wire;

  static NotificationInboxStatus fromWire(String wire) {
    for (final value in values) {
      if (value.wire == wire) return value;
    }
    throw FormatException('status desconocido: $wire');
  }
}

class NotificationInboxItem {
  const NotificationInboxItem({
    required this.id,
    required this.eventType,
    required this.title,
    required this.body,
    required this.priority,
    required this.count,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.botId,
    this.chatLid,
    this.labelId,
    this.payload = const {},
    this.coalesceKey,
    this.readAt,
  });

  final String id;
  final NotificationEventType eventType;
  final String? botId;
  final String? chatLid;
  final String? labelId;
  final String title;
  final String body;
  final NotificationPriority priority;
  final Map<String, String> payload;
  final String? coalesceKey;
  final int count;
  final NotificationInboxStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? readAt;

  bool get isUnread => status == NotificationInboxStatus.unread;

  NotificationInboxItem copyWith({
    NotificationInboxStatus? status,
    DateTime? readAt,
  }) => NotificationInboxItem(
    id: id,
    eventType: eventType,
    botId: botId,
    chatLid: chatLid,
    labelId: labelId,
    title: title,
    body: body,
    priority: priority,
    payload: payload,
    coalesceKey: coalesceKey,
    count: count,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt,
    readAt: readAt ?? this.readAt,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationInboxItem &&
      other.id == id &&
      other.eventType == eventType &&
      other.botId == botId &&
      other.chatLid == chatLid &&
      other.labelId == labelId &&
      other.title == title &&
      other.body == body &&
      other.priority == priority &&
      _sameStringMap(other.payload, payload) &&
      other.coalesceKey == coalesceKey &&
      other.count == count &&
      other.status == status &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.readAt == readAt;

  @override
  int get hashCode => Object.hash(
    id,
    eventType,
    botId,
    chatLid,
    labelId,
    title,
    body,
    priority,
    Object.hashAll(payload.entries.map((e) => Object.hash(e.key, e.value))),
    coalesceKey,
    count,
    status,
    createdAt,
    updatedAt,
    readAt,
  );
}

bool _sameStringMap(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
