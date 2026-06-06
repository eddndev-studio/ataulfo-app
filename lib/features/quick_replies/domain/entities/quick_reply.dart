/// Respuesta rápida de WhatsApp Business espejada del bot (S23, canal
/// no-oficial). Value object: dos instancias con la misma data son iguales.
///
/// `waQuickReplyId` es el id OPACO que asigna WhatsApp (no el shortcut): estable
/// aunque se renombre el atajo. `shortcut` es el atajo que el operador teclea en
/// la app de WhatsApp; `message` es el texto que se inserta al elegir la
/// respuesta. `deleted` es un tombstone explícito: el espejo es fiel al catálogo
/// de WhatsApp y puede devolver respuestas borradas; la UI no las ofrece.
///
/// El espejo del backend además guarda keywords/count/associatedLabelIds, pero el
/// selector ⚡ del composer no los usa: el cliente solo modela atajo + mensaje.
class QuickReply {
  const QuickReply({
    required this.waQuickReplyId,
    required this.shortcut,
    required this.message,
    required this.deleted,
  });

  final String waQuickReplyId;
  final String shortcut;
  final String message;
  final bool deleted;

  @override
  bool operator ==(Object other) =>
      other is QuickReply &&
      other.waQuickReplyId == waQuickReplyId &&
      other.shortcut == shortcut &&
      other.message == message &&
      other.deleted == deleted;

  @override
  int get hashCode => Object.hash(waQuickReplyId, shortcut, message, deleted);
}
