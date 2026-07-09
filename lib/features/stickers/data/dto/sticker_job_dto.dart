/// DTO del wire de un job de sticker (`GET /workspace/stickers`).
///
/// Las claves viajan en camelCase, como el resto del adaptador Go. Todos los
/// campos son obligatorios y el backend los emite siempre ('' para resultado
/// pendiente o sin error): un faltante o un tipo inválido es un wire roto.
/// `status` y `createdAt` se quedan como strings; el mapper los convierte.
class StickerJobDto {
  const StickerJobDto({
    required this.id,
    required this.motif,
    required this.model,
    required this.status,
    required this.resultMediaRef,
    required this.errorNote,
    required this.createdAt,
  });

  factory StickerJobDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final motif = json['motif'];
    final model = json['model'];
    final status = json['status'];
    final resultMediaRef = json['resultMediaRef'];
    final errorNote = json['errorNote'];
    final createdAt = json['createdAt'];
    if (id is! String ||
        motif is! String ||
        model is! String ||
        status is! String ||
        resultMediaRef is! String ||
        errorNote is! String ||
        createdAt is! String) {
      throw const FormatException(
        'sticker: clave obligatoria ausente o tipo inválido',
      );
    }
    return StickerJobDto(
      id: id,
      motif: motif,
      model: model,
      status: status,
      resultMediaRef: resultMediaRef,
      errorNote: errorNote,
      createdAt: createdAt,
    );
  }

  final String id;
  final String motif;
  final String model;
  final String status;
  final String resultMediaRef;
  final String errorNote;
  final String createdAt;
}
