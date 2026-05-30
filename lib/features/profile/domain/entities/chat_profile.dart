/// Perfil de un chat ("revisar perfil"): identidad + foto + app-state de la
/// conversación (S07/S09 `GET /sessions/:botId/:chatLid/profile`). Es la misma
/// fila de la bandeja más la foto consultada en vivo; el cliente la usa para el
/// header del hilo y la pantalla de perfil.
///
/// `isGroup` se deriva del `kind` del wire (fail-loud ante un valor desconocido,
/// en el mapper); el resto son los campos que la UI muestra. `photoUrl` es la
/// URL efímera del CDN de Meta (o `null` si no hay foto / no se pudo resolver) ⇒
/// la UI cae a las iniciales.
class ChatProfile {
  const ChatProfile({
    required this.chatLid,
    required this.isGroup,
    required this.phone,
    required this.displayName,
    required this.photoUrl,
    required this.isArchived,
    required this.isPinned,
    required this.isMarkedUnread,
    required this.mutedUntil,
  });

  final String chatLid;
  final bool isGroup;

  /// Phone del contacto (DM); `null` en grupos.
  final String? phone;

  /// Nombre visible (push-name DM / subject grupo); `null` si no resuelto.
  final String? displayName;

  /// Foto de perfil efímera, o `null` (sin foto / no resuelta).
  final String? photoUrl;

  final bool isArchived;
  final bool isPinned;
  final bool isMarkedUnread;

  /// Silenciado hasta este instante; `null` si no está silenciada.
  final DateTime? mutedUntil;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatProfile &&
        other.chatLid == chatLid &&
        other.isGroup == isGroup &&
        other.phone == phone &&
        other.displayName == displayName &&
        other.photoUrl == photoUrl &&
        other.isArchived == isArchived &&
        other.isPinned == isPinned &&
        other.isMarkedUnread == isMarkedUnread &&
        other.mutedUntil == mutedUntil;
  }

  @override
  int get hashCode => Object.hash(
    chatLid,
    isGroup,
    phone,
    displayName,
    photoUrl,
    isArchived,
    isPinned,
    isMarkedUnread,
    mutedUntil,
  );
}
