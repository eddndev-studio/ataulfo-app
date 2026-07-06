/// Límites de adjuntos POR TURNO de los chats de agentes (entrenador,
/// asistente y su sandbox de preview). Reflejan el límite server-side; se
/// aplican client-side ANTES de subir/enviar para no gastar red en lo que el
/// server igual rechazaría.
const int maxTurnAttachments = 5;

/// Peso máximo por archivo adjunto (25 MB).
const int maxTurnAttachmentBytes = 25 * 1024 * 1024;

/// Espejo client-side de la allowlist de content-types del servidor
/// (imagen JPG/PNG/WebP, PDF y video MP4), expresada como extensiones porque
/// el picker solo entrega bytes + filename. Gate rápido para no subir lo que
/// el server contestaría 415; el server sigue siendo la autoridad (sniffea
/// los bytes reales).
const Set<String> allowedTurnAttachmentExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'webp',
  'pdf',
  'mp4',
};

/// `true` si el nombre de archivo lleva una extensión de la allowlist.
bool isSupportedTurnAttachmentName(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return false;
  return allowedTurnAttachmentExtensions.contains(
    filename.substring(dot + 1).toLowerCase(),
  );
}
