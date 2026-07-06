part of 'media_gallery_bloc.dart';

// Events --------------------------------------------------------------------

sealed class MediaGalleryEvent {
  const MediaGalleryEvent();
}

/// Pide la primera página (reemplaza cualquier contenido).
class MediaGalleryLoadRequested extends MediaGalleryEvent {
  const MediaGalleryLoadRequested();
  @override
  bool operator ==(Object other) => other is MediaGalleryLoadRequested;
  @override
  int get hashCode => (MediaGalleryLoadRequested).hashCode;
}

/// Pide la siguiente página usando el `nextCursor` actual. No-op si no hay más
/// páginas o si ya hay una carga en curso.
class MediaGalleryLoadMoreRequested extends MediaGalleryEvent {
  const MediaGalleryLoadMoreRequested();
  @override
  bool operator ==(Object other) => other is MediaGalleryLoadMoreRequested;
  @override
  int get hashCode => (MediaGalleryLoadMoreRequested).hashCode;
}

/// Recarga la primera página manteniendo la lista visible (pull-to-refresh).
class MediaGalleryRefreshRequested extends MediaGalleryEvent {
  const MediaGalleryRefreshRequested();
  @override
  bool operator ==(Object other) => other is MediaGalleryRefreshRequested;
  @override
  int get hashCode => (MediaGalleryRefreshRequested).hashCode;
}

/// Elige un archivo (puerto FilePicker), lo sube y re-lista para mostrarlo con
/// metadata completa del servidor.
class MediaGalleryUploadRequested extends MediaGalleryEvent {
  const MediaGalleryUploadRequested();
  @override
  bool operator ==(Object other) => other is MediaGalleryUploadRequested;
  @override
  int get hashCode => (MediaGalleryUploadRequested).hashCode;
}

/// Cambia el término de búsqueda (filename/alias) y recarga la primera página.
/// La UI lo despacha con debounce; el bloc descarta resultados obsoletos.
class MediaGallerySearchChanged extends MediaGalleryEvent {
  const MediaGallerySearchChanged(this.query);

  final String query;

  @override
  bool operator ==(Object other) =>
      other is MediaGallerySearchChanged && other.query == query;
  @override
  int get hashCode => Object.hash(MediaGallerySearchChanged, query);
}

/// Cambia la familia filtrada (image|video|audio|document, o null = todas) y
/// recarga la primera página. Sólo lo despachan las tabs de browse.
class MediaGalleryTypeChanged extends MediaGalleryEvent {
  const MediaGalleryTypeChanged(this.type);

  final String? type;

  @override
  bool operator ==(Object other) =>
      other is MediaGalleryTypeChanged && other.type == type;
  @override
  int get hashCode => Object.hash(MediaGalleryTypeChanged, type);
}

/// Limpia búsqueda y familia de una sola vez (una recarga). En un picker con
/// tipo fijo, la familia vuelve a la restricción del caller, no a null.
class MediaGalleryFiltersCleared extends MediaGalleryEvent {
  const MediaGalleryFiltersCleared();
  @override
  bool operator ==(Object other) => other is MediaGalleryFiltersCleared;
  @override
  int get hashCode => (MediaGalleryFiltersCleared).hashCode;
}

/// Alterna la selección de un asset por su ref BARE (modo selección múltiple).
class MediaGallerySelectionToggled extends MediaGalleryEvent {
  const MediaGallerySelectionToggled(this.ref);

  final String ref;

  @override
  bool operator ==(Object other) =>
      other is MediaGallerySelectionToggled && other.ref == ref;
  @override
  int get hashCode => Object.hash(MediaGallerySelectionToggled, ref);
}

/// Vacía la selección (sale del modo selección).
class MediaGallerySelectionCleared extends MediaGalleryEvent {
  const MediaGallerySelectionCleared();
  @override
  bool operator ==(Object other) => other is MediaGallerySelectionCleared;
  @override
  int get hashCode => (MediaGallerySelectionCleared).hashCode;
}

/// Borra en lote los assets seleccionados y re-lista.
class MediaGalleryDeleteSelectedRequested extends MediaGalleryEvent {
  const MediaGalleryDeleteSelectedRequested();
  @override
  bool operator ==(Object other) =>
      other is MediaGalleryDeleteSelectedRequested;
  @override
  int get hashCode => (MediaGalleryDeleteSelectedRequested).hashCode;
}

/// Cancela el borrado en lote en curso: no se emiten más deletes (el que está
/// en vuelo termina) y se re-lista con lo que alcanzó a borrarse.
class MediaGalleryDeleteCancelRequested extends MediaGalleryEvent {
  const MediaGalleryDeleteCancelRequested();
  @override
  bool operator ==(Object other) => other is MediaGalleryDeleteCancelRequested;
  @override
  int get hashCode => (MediaGalleryDeleteCancelRequested).hashCode;
}
