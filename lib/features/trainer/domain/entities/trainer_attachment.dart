/// Adjunto de un turno del hilo del entrenador. La ref es la moneda del
/// wire: la subida la devuelve, el POST de mensaje la manda y el server
/// resuelve mime/name/size de su registro (el cliente solo pinta chips).
class TrainerAttachment {
  const TrainerAttachment({
    required this.ref,
    required this.mime,
    required this.name,
    required this.sizeBytes,
    this.url,
  });

  final String ref;
  final String mime;
  final String name;
  final int sizeBytes;

  /// URL firmada de preview, best-effort del wire (`null` si no viajó). Es
  /// efímera —la firma expira—: sirve como fuente de respaldo cuando no hay
  /// copia local en caché (adjunto de otro dispositivo / historial previo);
  /// la identidad estable del binario sigue siendo [ref].
  final String? url;

  @override
  bool operator ==(Object other) =>
      other is TrainerAttachment &&
      other.ref == ref &&
      other.mime == mime &&
      other.name == name &&
      other.sizeBytes == sizeBytes &&
      other.url == url;

  @override
  int get hashCode => Object.hash(ref, mime, name, sizeBytes, url);
}
