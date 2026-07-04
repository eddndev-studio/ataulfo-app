/// Adjunto de un turno del asistente de plataforma. La ref es la moneda del
/// wire: la subida la devuelve, el POST de mensaje la manda y el server
/// resuelve mime/name/size de su registro (el cliente solo pinta chips).
class PaAttachment {
  const PaAttachment({
    required this.ref,
    required this.mime,
    required this.name,
    required this.sizeBytes,
  });

  final String ref;
  final String mime;
  final String name;
  final int sizeBytes;

  @override
  bool operator ==(Object other) =>
      other is PaAttachment &&
      other.ref == ref &&
      other.mime == mime &&
      other.name == name &&
      other.sizeBytes == sizeBytes;

  @override
  int get hashCode => Object.hash(ref, mime, name, sizeBytes);
}
