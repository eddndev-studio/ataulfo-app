/// Tope de archivos por lote de envío.
const int kMaxAttachmentsPerBatch = 10;

/// Tope de peso por archivo (64 MB) que el cliente aplica ANTES de subir, para
/// no gastar una subida que el `/upload` rechazaría igual.
const int kMaxAttachmentBytes = 64 * 1024 * 1024;

/// Resultado de admitir un lote de adjuntos elegidos contra los topes
/// client-side: qué índices se aceptan y por qué se rechazó lo demás
/// (peso o cupo del lote), para que el composer dé copy específica.
class AttachmentIntake {
  const AttachmentIntake({
    required this.acceptedIndexes,
    required this.tooLarge,
    required this.overflow,
  });

  /// Índices (en el orden de entrada) de los adjuntos aceptados.
  final List<int> acceptedIndexes;

  /// Nombres de los rechazados por superar el tope de peso.
  final List<String> tooLarge;

  /// Alguno no cupo por el tope de cantidad del lote.
  final bool overflow;
}

/// Decide qué adjuntos entran a la bandeja aplicando los topes client-side. Puro
/// (sin bytes reales: recibe sólo tamaño y nombre) para testear los límites sin
/// materializar archivos grandes. Los pesados se descartan primero y NO ocupan
/// cupo; el resto entra en orden hasta llenar el tope de [maxBatch] contando los
/// [currentCount] ya presentes.
AttachmentIntake planAttachmentBatch({
  required List<({String filename, int sizeBytes})> picked,
  required int currentCount,
  int maxBatch = kMaxAttachmentsPerBatch,
  int maxFileBytes = kMaxAttachmentBytes,
}) {
  final accepted = <int>[];
  final tooLarge = <String>[];
  var overflow = false;
  for (var i = 0; i < picked.length; i++) {
    final item = picked[i];
    if (item.sizeBytes > maxFileBytes) {
      tooLarge.add(item.filename);
      continue;
    }
    if (currentCount + accepted.length < maxBatch) {
      accepted.add(i);
    } else {
      overflow = true;
    }
  }
  return AttachmentIntake(
    acceptedIndexes: accepted,
    tooLarge: tooLarge,
    overflow: overflow,
  );
}
