import 'conversation.dart';

enum InboxStatus {
  all,
  unread,
  attention,
  archived;

  String get wireName => name;
}

const Object _notProvided = Object();

/// Filtros componibles de la Bandeja. Las facetas se cruzan con AND, pero la
/// etiqueta es deliberadamente singular: canal + una etiqueta pueden convivir;
/// dos etiquetas simultáneas son un estado que el modelo no puede representar.
class InboxQuery {
  const InboxQuery({
    this.search = '',
    this.status = InboxStatus.all,
    this.botId,
    this.labelId,
    this.cursor,
    this.limit = 40,
  });

  final String search;
  final InboxStatus status;
  final String? botId;
  final String? labelId;
  final String? cursor;
  final int limit;

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      status != InboxStatus.all ||
      botId != null ||
      labelId != null;

  InboxQuery copyWith({
    String? search,
    InboxStatus? status,
    Object? botId = _notProvided,
    Object? labelId = _notProvided,
    Object? cursor = _notProvided,
    int? limit,
  }) => InboxQuery(
    search: search ?? this.search,
    status: status ?? this.status,
    botId: identical(botId, _notProvided) ? this.botId : botId as String?,
    labelId: identical(labelId, _notProvided)
        ? this.labelId
        : labelId as String?,
    cursor: identical(cursor, _notProvided) ? this.cursor : cursor as String?,
    limit: limit ?? this.limit,
  );

  InboxQuery get firstPage => copyWith(cursor: null);

  /// Filtro equivalente sobre la caché. HTTP sigue siendo autoritativo; esto
  /// permite una primera vista útil sin conexión y nunca amplía permisos.
  bool matches(Conversation conversation) {
    if (botId != null && conversation.botId != botId) return false;

    final matchesStatus = switch (status) {
      InboxStatus.all => !conversation.isArchived,
      InboxStatus.unread =>
        !conversation.isArchived &&
            (conversation.unreadCount > 0 || conversation.isMarkedUnread),
      InboxStatus.attention =>
        !conversation.isArchived && conversation.needsAttention,
      InboxStatus.archived => conversation.isArchived,
    };
    if (!matchesStatus) return false;

    if (labelId case final selectedLabel?) {
      final presentLabels = <String>{for (final l in conversation.labels) l.id};
      if (!presentLabels.contains(selectedLabel)) return false;
    }

    final needle = search.trim().toLowerCase();
    if (needle.isEmpty) return true;
    final haystack = <String?>[
      conversation.displayName,
      conversation.phone,
      conversation.assistantName,
      conversation.channelName,
      conversation.channelIdentifier,
    ];
    return haystack.any(
      (value) => value?.toLowerCase().contains(needle) ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is InboxQuery &&
      other.search == search &&
      other.status == status &&
      other.botId == botId &&
      other.labelId == labelId &&
      other.cursor == cursor &&
      other.limit == limit;

  @override
  int get hashCode =>
      Object.hash(search, status, botId, labelId, cursor, limit);
}

/// Orden de respaldo para la caché: fijadas, actividad descendente y desempate
/// determinista por identidad compuesta, igual que el contrato del servidor.
int compareInboxConversations(Conversation a, Conversation b) {
  if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
  final timestamp = (b.lastMessageTimestampMs ?? 0).compareTo(
    a.lastMessageTimestampMs ?? 0,
  );
  if (timestamp != 0) return timestamp;
  final bot = a.botId.compareTo(b.botId);
  return bot != 0 ? bot : a.chatLid.compareTo(b.chatLid);
}
