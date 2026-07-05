/// Clase de un adjunto derivada de su MIME. Es una clasificación de
/// PRESENTACIÓN (qué renderer usa la burbuja), no del wire: el server manda el
/// MIME y el cliente decide cómo pintarlo.
enum AttachmentKind { image, video, audio, document }

/// Deriva la clase de adjunto del MIME (`image/*`, `video/*`, `audio/*`; el
/// resto —PDF, texto, vacío o malformado— cae a documento). Tolera mayúsculas,
/// espacios y parámetros (`audio/ogg; codecs=opus`).
AttachmentKind attachmentKindForMime(String mime) {
  final m = mime.trim().toLowerCase();
  if (m.startsWith('image/')) return AttachmentKind.image;
  if (m.startsWith('video/')) return AttachmentKind.video;
  if (m.startsWith('audio/')) return AttachmentKind.audio;
  return AttachmentKind.document;
}
