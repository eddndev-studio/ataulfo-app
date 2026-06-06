import 'dart:convert';

/// Helpers de presentación para mostrar el recurso de un paso multimedia con un
/// nombre legible en lugar del `ref` BARE opaco. El nombre real del archivo se
/// guarda en `Step.metadata` bajo `media_filename` al elegir el recurso (espejo
/// de `MediaMetadata.FileName` del backend, que WhatsApp usa como nombre del
/// adjunto). Cuando no se guardó uno, se cae a la cola corta del ref.

/// Extrae `media_filename` del metadata JSON de un paso. Ausente, vacío,
/// en blanco o corrupto ⇒ null (el caller decide el fallback). No lanza: un
/// metadata malformado se trata como "sin nombre", no como error de UI.
String? mediaFilenameFromMetadata(String metadataJson) {
  if (metadataJson.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(metadataJson);
    if (decoded is Map<String, dynamic>) {
      final name = decoded['media_filename'];
      if (name is String && name.trim().isNotEmpty) return name;
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// Cola corta del ref BARE: el último segmento del path (el nombre/id del
/// archivo). Si el ref no tiene `/` o termina en `/`, se devuelve completo.
/// Es lo más parecido a un nombre cuando el paso no guardó un `media_filename`.
String shortMediaRef(String ref) {
  final slash = ref.lastIndexOf('/');
  if (slash < 0 || slash == ref.length - 1) return ref;
  return ref.substring(slash + 1);
}

/// Texto a mostrar para el recurso de un paso multimedia en la lista de pasos,
/// junto con si debe renderizarse en monospace. Prefiere el nombre real del
/// archivo (`media_filename` del metadata); si no hay uno guardado, cae a la
/// cola corta del ref BARE en monospace (placeholder honesto: es un id, no un
/// nombre). El caller garantiza `mediaRef` no vacío.
(String text, bool mono) mediaStepDisplay({
  required String mediaRef,
  required String metadataJson,
}) {
  final name = mediaFilenameFromMetadata(metadataJson);
  if (name != null && name.isNotEmpty) return (name, false);
  return (shortMediaRef(mediaRef), true);
}
