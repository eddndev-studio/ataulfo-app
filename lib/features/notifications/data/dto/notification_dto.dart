class NotificationPreferenceResp {
  const NotificationPreferenceResp({
    required this.eventType,
    required this.enabled,
    required this.botFilter,
    required this.labelFilter,
    required this.priority,
    this.quietHours,
  });

  factory NotificationPreferenceResp.fromJson(Map<String, dynamic> json) =>
      NotificationPreferenceResp(
        eventType: json['eventType'] as String,
        enabled: json['enabled'] as bool,
        botFilter: NotificationBotFilterResp.fromJson(
          json['botFilter'] as Map<String, dynamic>,
        ),
        labelFilter: _stringList(json['labelFilter']),
        priority: json['priority'] as String,
        quietHours: json['quietHours'] == null
            ? null
            : NotificationQuietHoursResp.fromJson(
                json['quietHours'] as Map<String, dynamic>,
              ),
      );

  final String eventType;
  final bool enabled;
  final NotificationBotFilterResp botFilter;
  final List<String> labelFilter;
  final String priority;
  final NotificationQuietHoursResp? quietHours;
}

class NotificationBotFilterResp {
  const NotificationBotFilterResp({required this.all, required this.botIds});

  factory NotificationBotFilterResp.fromJson(Map<String, dynamic> json) =>
      NotificationBotFilterResp(
        all: json['all'] as bool,
        botIds: _stringList(json['botIds']),
      );

  final bool all;
  final List<String> botIds;
}

class NotificationQuietHoursResp {
  const NotificationQuietHoursResp({
    required this.start,
    required this.end,
    required this.timeZone,
  });

  factory NotificationQuietHoursResp.fromJson(Map<String, dynamic> json) =>
      NotificationQuietHoursResp(
        start: json['start'] as String,
        end: json['end'] as String,
        timeZone: json['timeZone'] as String,
      );

  final String start;
  final String end;
  final String timeZone;
}

class NotificationInboxResp {
  const NotificationInboxResp({
    required this.id,
    required this.eventType,
    required this.title,
    required this.body,
    required this.priority,
    required this.payload,
    required this.count,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.botId,
    this.chatLid,
    this.labelId,
    this.coalesceKey,
    this.readAt,
  });

  factory NotificationInboxResp.fromJson(Map<String, dynamic> json) =>
      NotificationInboxResp(
        id: json['id'] as String,
        eventType: json['eventType'] as String,
        botId: json['botId'] as String?,
        chatLid: json['chatLID'] as String?,
        labelId: json['labelId'] as String?,
        title: json['title'] as String,
        body: json['body'] as String,
        priority: json['priority'] as String,
        payload: _stringMap(json['payload']),
        coalesceKey: json['coalesceKey'] as String?,
        count: json['count'] as int,
        status: json['status'] as String,
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
        readAt: json['readAt'] as String?,
      );

  final String id;
  final String eventType;
  final String? botId;
  final String? chatLid;
  final String? labelId;
  final String title;
  final String body;
  final String priority;
  final Map<String, String> payload;
  final String? coalesceKey;
  final int count;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? readAt;
}

List<String> _stringList(Object? raw) {
  if (raw == null) return const <String>[];
  return (raw as List<dynamic>).cast<String>();
}

Map<String, String> _stringMap(Object? raw) {
  if (raw == null) return const <String, String>{};
  return (raw as Map<String, dynamic>).map(
    (key, value) => MapEntry(key, value as String),
  );
}
