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
/// Slice 1 = identidad + app-state. Sin último-mensaje ni no-leídos (no vienen
/// en el contrato todavía) y sin nombre visible (el backend aún no tiene
/// columna name; las DM se identifican por `phone`).
class Conversation {
  const Conversation({
    required this.chatLid,
    required this.kind,
    required this.phone,
    required this.isArchived,
    required this.isPinned,
    required this.isMarkedUnread,
    required this.mutedUntil,
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
        other.mutedUntil == mutedUntil;
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
  );
}
