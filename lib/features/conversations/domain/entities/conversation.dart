/// Tipo de conversación (S07 `Session.kind`): mensaje directo o grupo. Se
/// recibe explícito del wire — NO se infiere del formato del chatLID (deducir
/// `@g.us` es la clase de bug heredada que el backend rechaza).
///
/// Política fail-loud ante un valor desconocido: si el backend agrega un kind
/// nuevo, el cliente DEBE romper al parsear en vez de degradar a un "unknown"
/// cosmético que escondería drift de contrato.
enum ConversationKind {
  dm,
  group;

  static ConversationKind fromWire(String raw) => switch (raw) {
    'DM' => ConversationKind.dm,
    'GROUP' => ConversationKind.group,
    _ => throw ArgumentError.value(raw, 'ConversationKind.fromWire'),
  };
}

/// Una conversación (contacto/chat) de un bot. Es la entidad `Session` de S07
/// del backend (`GET /sessions/:botId`); en el cliente se llama Conversation
/// para no chocar con la "sesión de canal" del bot (start/stop/pairing), que
/// es otra cosa. Los mappers traducen el DTO del wire (`chat_lid`, etc.) a
/// esta entidad sin nombres `snake_case`.
///
/// Identidad + app-state + **actividad** de la bandeja: nombre visible
/// (`displayName`), último-mensaje (preview/tipo/dirección/instante) y conteo
/// de no-leídos. La actividad es opcional: una conversación sin mensajes la
/// trae vacía (`unreadCount` 0, último-mensaje `null`); el mapper la rellena
/// desde el wire cuando viene.
class Conversation {
  const Conversation({
    required this.chatLid,
    required this.kind,
    required this.phone,
    required this.isArchived,
    required this.isPinned,
    required this.isMarkedUnread,
    required this.mutedUntil,
    this.displayName,
    this.unreadCount = 0,
    this.lastMessagePreview,
    this.lastMessageType,
    this.lastMessageDirection,
    this.lastMessageTimestampMs,
  });

  final String chatLid;
  final ConversationKind kind;

  /// Mapping secundario phone/JID. DM-only: `null` en grupos (un grupo no
  /// tiene phone, S07).
  final String? phone;

  // Espejo de app-state de WhatsApp.
  final bool isArchived;
  final bool isPinned;
  final bool isMarkedUnread;

  /// Silenciado hasta este instante; `null` si no está silenciada.
  final DateTime? mutedUntil;

  /// Nombre visible: push-name en DM, subject en grupo. `null` cuando el
  /// backend aún no lo resolvió ⇒ la UI cae a `phone`/"Grupo".
  final String? displayName;

  /// Conteo de mensajes entrantes sin leer. Ortogonal a [isMarkedUnread] (ese
  /// es el flag "marcar como no leído" de WhatsApp; este es el contador real).
  final int unreadCount;

  /// Último-mensaje de la conversación (proyección de la bandeja). `null`
  /// cuando la conversación aún no tiene mensajes; los cuatro viajan juntos.
  final String? lastMessagePreview;
  final String? lastMessageType;
  final String? lastMessageDirection;
  final int? lastMessageTimestampMs;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Conversation &&
        other.chatLid == chatLid &&
        other.kind == kind &&
        other.phone == phone &&
        other.isArchived == isArchived &&
        other.isPinned == isPinned &&
        other.isMarkedUnread == isMarkedUnread &&
        other.mutedUntil == mutedUntil &&
        other.displayName == displayName &&
        other.unreadCount == unreadCount &&
        other.lastMessagePreview == lastMessagePreview &&
        other.lastMessageType == lastMessageType &&
        other.lastMessageDirection == lastMessageDirection &&
        other.lastMessageTimestampMs == lastMessageTimestampMs;
  }

  @override
  int get hashCode => Object.hash(
    chatLid,
    kind,
    phone,
    isArchived,
    isPinned,
    isMarkedUnread,
    mutedUntil,
    displayName,
    unreadCount,
    lastMessagePreview,
    lastMessageType,
    lastMessageDirection,
    lastMessageTimestampMs,
  );
}
