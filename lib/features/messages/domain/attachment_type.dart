/// Infiere el `type` de envío de un adjunto a partir del nombre del archivo
/// (S09: `image`/`video`/`audio`/`document`). Un mapa propio de extensiones
/// evita una dependencia extra sólo para clasificar; lo que no cae en imagen,
/// video o audio es un `document` (WhatsApp acepta cualquier archivo como
/// documento). La extensión es la última tras el punto final, en minúsculas;
/// sin extensión ⇒ `document`.
String messageTypeForFilename(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return 'document';
  final ext = filename.substring(dot + 1).toLowerCase();
  if (_imageExts.contains(ext)) return 'image';
  if (_videoExts.contains(ext)) return 'video';
  if (_audioExts.contains(ext)) return 'audio';
  return 'document';
}

const Set<String> _imageExts = <String>{
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
  'tiff',
  'tif',
};

const Set<String> _videoExts = <String>{
  'mp4',
  'mov',
  'avi',
  'mkv',
  'webm',
  '3gp',
  'm4v',
  'mpeg',
  'mpg',
};

const Set<String> _audioExts = <String>{
  'mp3',
  'ogg',
  'opus',
  'm4a',
  'aac',
  'wav',
  'flac',
  'amr',
};
