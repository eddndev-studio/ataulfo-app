/// Estado de un job de sticker. Set cerrado del backend; el wire viaja en
/// mayúsculas (`QUEUED`/`RUNNING`/`DONE`/`FAILED`) y el mapper convierte.
enum StickerStatus { queued, running, done, failed }

/// Job de generación de un sticker: la IA dibuja el motivo y lo recorta a un
/// webp transparente. [resultMediaRef] es el ref BARE del sticker en la galería
/// ('' mientras no termina); [errorNote] explica un FAILED ('' en el resto).
class StickerJob {
  const StickerJob({
    required this.id,
    required this.motif,
    required this.status,
    required this.resultMediaRef,
    required this.errorNote,
    required this.createdAt,
  });

  final String id;

  /// Id del motivo (`gracias`, `oferta`, …). Valor de wire; el rótulo humano
  /// vive en presentación.
  final String motif;

  final StickerStatus status;
  final String resultMediaRef;
  final String errorNote;
  final DateTime createdAt;

  /// El backend sigue trabajando: la UI lo espera con poll.
  bool get isActive =>
      status == StickerStatus.queued || status == StickerStatus.running;

  /// Sticker usable: terminó y tiene su ref de galería.
  bool get isReady => status == StickerStatus.done && resultMediaRef.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is StickerJob &&
      other.id == id &&
      other.motif == motif &&
      other.status == status &&
      other.resultMediaRef == resultMediaRef &&
      other.errorNote == errorNote &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, motif, status, resultMediaRef, errorNote, createdAt);
}
