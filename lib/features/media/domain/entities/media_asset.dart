/// Un archivo subido al catálogo de media de la organización.
///
/// Identidad: [ref] es el identificador BARE canónico (p. ej.
/// `tenant/org/media/abc.png`). Es lo que viaja a los steps de un flujo y se
/// persiste: estable y permanente.
///
/// [previewUrl] es una URL firmada EFÍMERA, sólo para mostrar la miniatura en
/// la galería. Expira; NUNCA se persiste ni se usa como identidad. El nombre
/// del campo (no `url`) lleva esa semántica: cualquier consumidor que quiera
/// "el archivo" usa [ref], no [previewUrl].
class MediaAsset {
  const MediaAsset({
    required this.ref,
    required this.previewUrl,
    required this.filename,
    required this.contentType,
    required this.size,
    required this.createdAt,
    this.alias = '',
  });

  /// Identificador BARE canónico del archivo. Sin esquema ni query de firma.
  final String ref;

  /// URL firmada de previsualización (efímera). `null` cuando el backend no la
  /// emite (omitempty del wire).
  final String? previewUrl;

  /// Nombre original de subida (inmutable).
  final String filename;

  /// Nombre amistoso editable, SEPARADO del [filename]. Vacío (default) ⇒ la UI
  /// muestra el [filename]. Es presentación, jamás identidad (esa es [ref]).
  final String alias;

  final String contentType;

  /// Nombre a mostrar en la galería: el [alias] si no está vacío, si no el
  /// [filename] original. Centraliza la regla I-MA3 para que ningún widget la
  /// reimplemente.
  String get displayName => alias.isNotEmpty ? alias : filename;

  /// Tamaño en bytes reportado por el servidor.
  final int size;

  /// Instante de creación (UTC del wire).
  final DateTime createdAt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaAsset &&
        other.ref == ref &&
        other.previewUrl == previewUrl &&
        other.filename == filename &&
        other.alias == alias &&
        other.contentType == contentType &&
        other.size == size &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    ref,
    previewUrl,
    filename,
    alias,
    contentType,
    size,
    createdAt,
  );
}

/// Resultado MÍNIMO de una subida (`POST /upload`). El backend sólo devuelve
/// `{ref, url?}` — NO trae filename/size/content_type/created_at. Por eso este
/// value object NO es un [MediaAsset]: fabricar metadata (p. ej. un `createdAt`
/// local adivinado) sería inventar verdad que el servidor no dio. El render del
/// asset con metadata completa se obtiene RE-LISTANDO contra `/media-assets`.
class UploadedMedia {
  const UploadedMedia({required this.ref, required this.previewUrl});

  /// Identificador BARE canónico del archivo recién subido.
  final String ref;

  /// URL firmada de previsualización (efímera), o `null` (omitempty del wire).
  final String? previewUrl;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UploadedMedia &&
        other.ref == ref &&
        other.previewUrl == previewUrl;
  }

  @override
  int get hashCode => Object.hash(ref, previewUrl);
}

/// Una página del listado paginado de media. [nextCursor] vacío significa que
/// no hay más páginas; un valor opaco se reenvía como `cursor` en la siguiente
/// llamada. El scroll-infinito que consume esto vive en la capa de presentación.
class MediaPage {
  const MediaPage({required this.assets, required this.nextCursor});

  final List<MediaAsset> assets;

  /// Cursor opaco para la siguiente página; vacío ⇒ no hay más.
  final String nextCursor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MediaPage || other.nextCursor != nextCursor) return false;
    if (other.assets.length != assets.length) return false;
    for (var i = 0; i < assets.length; i++) {
      if (other.assets[i] != assets[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(nextCursor, Object.hashAll(assets));
}
