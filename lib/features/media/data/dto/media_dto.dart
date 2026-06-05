/// DTOs del wire de Media (`POST /upload`, `GET /media-assets`). Mantienen los
/// nombres `snake_case` y los tipos crudos del wire; la traducción a dominio
/// (ref BARE vs previewUrl, created_at → DateTime) vive en `MediaMapper`.
///
/// `fromJson` manual con validación inline estricta (no json_serializable ni
/// freezed: decisión de diseño del repo). Campo obligatorio ausente o de tipo
/// equivocado ⇒ `FormatException`. Campos nullable = `omitempty` del backend.
library;

/// Respuesta de `POST /upload`: `{ "ref": "<bare>", "url": "<signed>"? }`.
class UploadResp {
  const UploadResp({required this.ref, this.url});

  factory UploadResp.fromJson(Map<String, dynamic> json) {
    final ref = json['ref'];
    final url = json['url'];
    if (ref is! String) {
      throw const FormatException('uploadResp: ref ausente o no String');
    }
    if (url != null && url is! String) {
      throw const FormatException('uploadResp: url no es String ni null');
    }
    return UploadResp(ref: ref, url: url as String?);
  }

  /// Identificador BARE canónico del archivo.
  final String ref;

  /// URL firmada de previsualización (efímera), o `null` (omitempty).
  final String? url;
}

/// Un asset del listado (`GET /media-assets`).
class MediaAssetResp {
  const MediaAssetResp({
    required this.ref,
    required this.filename,
    required this.contentType,
    required this.size,
    required this.createdAt,
    this.url,
    this.alias = '',
  });

  factory MediaAssetResp.fromJson(Map<String, dynamic> json) {
    final ref = json['ref'];
    final url = json['url'];
    final filename = json['filename'];
    final alias = json['alias'];
    final contentType = json['content_type'];
    final size = json['size'];
    final createdAt = json['created_at'];
    if (ref is! String ||
        filename is! String ||
        contentType is! String ||
        size is! int ||
        createdAt is! String) {
      throw const FormatException('mediaAssetResp: clave obligatoria ausente');
    }
    if (url != null && url is! String) {
      throw const FormatException('mediaAssetResp: url no es String ni null');
    }
    // alias es omitempty del wire: ausente o null ⇒ "" (sin alias). Presente y
    // no-String es un contrato roto.
    if (alias != null && alias is! String) {
      throw const FormatException('mediaAssetResp: alias no es String ni null');
    }
    return MediaAssetResp(
      ref: ref,
      url: url as String?,
      filename: filename,
      alias: (alias as String?) ?? '',
      contentType: contentType,
      size: size,
      createdAt: createdAt,
    );
  }

  /// Identificador BARE canónico.
  final String ref;

  /// URL firmada de previsualización (efímera), o `null` (omitempty).
  final String? url;

  final String filename;

  /// Nombre amistoso editable (omitempty del wire ⇒ "" cuando no hay alias).
  final String alias;

  final String contentType;
  final int size;

  /// ISO-8601 crudo del wire; el mapper lo parsea a `DateTime`.
  final String createdAt;
}

/// Envelope del listado: `{ "assets": [...], "next_cursor": "<opaco|"">" }`.
class MediaListResp {
  const MediaListResp({required this.assets, required this.nextCursor});

  factory MediaListResp.fromJson(Map<String, dynamic> json) {
    final assets = json['assets'];
    final nextCursor = json['next_cursor'];
    if (assets is! List || nextCursor is! String) {
      throw const FormatException(
        'mediaListResp: assets no es lista o next_cursor ausente',
      );
    }
    return MediaListResp(
      assets: assets
          .cast<Map<String, dynamic>>()
          .map(MediaAssetResp.fromJson)
          .toList(growable: false),
      nextCursor: nextCursor,
    );
  }

  final List<MediaAssetResp> assets;

  /// Cursor opaco de la siguiente página; vacío ⇒ no hay más.
  final String nextCursor;
}
