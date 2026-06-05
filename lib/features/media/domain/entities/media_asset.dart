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
    this.thumbnailUrl,
    this.durationMs,
  });

  /// Identificador BARE canónico del archivo. Sin esquema ni query de firma.
  final String ref;

  /// URL firmada de previsualización (efímera). `null` cuando el backend no la
  /// emite (omitempty del wire). Para una imagen es la imagen misma; para
  /// video/audio es el ARCHIVO ORIGINAL (no renderable como imagen) — la
  /// miniatura renderable de esos vive en [thumbnailUrl].
  final String? previewUrl;

  /// URL firmada (efímera) de la MINIATURA derivada por el backend: el poster
  /// de un video o la forma de onda de un audio. `null` cuando no hay derivado
  /// (aún sin generar, o tipo sin miniatura como imagen/documento). NUNCA
  /// identidad —como [previewUrl], expira—.
  final String? thumbnailUrl;

  /// Duración del medio en milisegundos (video/audio). `null` cuando no se
  /// conoce o no aplica (imagen/documento).
  final int? durationMs;

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

  /// URL de una imagen RENDERABLE para la miniatura del grid: el poster/forma
  /// de onda derivado ([thumbnailUrl]) si existe; si no, la [previewUrl] SÓLO
  /// cuando el asset es una imagen (su preview ES la imagen). Para video/audio/
  /// documento sin derivado ⇒ `null`, y el consumidor cae al ícono por tipo.
  /// Centraliza la regla para que ni el loader ni los widgets la reimplementen.
  String? get thumbnailSourceUrl {
    final t = thumbnailUrl;
    if (t != null && t.isNotEmpty) return t;
    if (contentType.startsWith('image/')) return previewUrl;
    return null;
  }

  /// Copia con campos sobreescritos. El uso principal es actualizar el [alias]
  /// in-place tras un rename sin re-listar (el resto de campos son inmutables
  /// para un mismo [ref]). Los derivados ([thumbnailUrl]/[durationMs]) se
  /// conservan: un rename no debe perder la miniatura ya resuelta.
  MediaAsset copyWith({String? alias}) => MediaAsset(
    ref: ref,
    previewUrl: previewUrl,
    filename: filename,
    alias: alias ?? this.alias,
    contentType: contentType,
    size: size,
    createdAt: createdAt,
    thumbnailUrl: thumbnailUrl,
    durationMs: durationMs,
  );

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
        other.createdAt == createdAt &&
        other.thumbnailUrl == thumbnailUrl &&
        other.durationMs == durationMs;
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
    thumbnailUrl,
    durationMs,
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
