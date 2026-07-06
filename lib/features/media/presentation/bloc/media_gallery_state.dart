part of 'media_gallery_bloc.dart';

// States --------------------------------------------------------------------

/// Resultado TRANSITORIO del último lote de subida, para el feedback de la UI:
/// cuántos archivos se intentaron, cuántos fallaron (con el último error como
/// muestra) y si algún subido con éxito quedó fuera de la lista visible por los
/// filtros activos (para ofrecer "Ver todo" en vez de desaparecerlo).
class MediaUploadOutcome {
  const MediaUploadOutcome({
    required this.total,
    required this.failed,
    this.lastError,
    this.hiddenByFilter = false,
  });

  /// Archivos intentados en el lote.
  final int total;

  /// Cuántos fallaron (0 ⇒ todo subió).
  final int failed;

  /// Último error observado (muestra; el conteo real es [failed]). También
  /// captura un fallo del re-list final aunque [failed] sea 0.
  final MediaFailure? lastError;

  /// Al menos un archivo subido con éxito NO aparece en la primera página
  /// re-listada con filtros activos: está en el servidor pero oculto.
  final bool hiddenByFilter;

  @override
  bool operator ==(Object other) =>
      other is MediaUploadOutcome &&
      other.total == total &&
      other.failed == failed &&
      other.lastError == lastError &&
      other.hiddenByFilter == hiddenByFilter;

  @override
  int get hashCode => Object.hash(total, failed, lastError, hiddenByFilter);
}

sealed class MediaGalleryState {
  const MediaGalleryState();
}

class MediaGalleryInitial extends MediaGalleryState {
  const MediaGalleryInitial();
  @override
  bool operator ==(Object other) => other is MediaGalleryInitial;
  @override
  int get hashCode => (MediaGalleryInitial).hashCode;
}

/// Primera carga (no hay lista que mostrar todavía).
class MediaGalleryLoading extends MediaGalleryState {
  const MediaGalleryLoading();
  @override
  bool operator ==(Object other) => other is MediaGalleryLoading;
  @override
  int get hashCode => (MediaGalleryLoading).hashCode;
}

/// Catálogo cargado. [nextCursor] vacío ⇒ no hay más páginas ([hasMore] lo
/// deriva). [isLoadingMore] marca una página en vuelo; [isUploading] una
/// subida en curso. [isRefreshing] marca un pull-to-refresh en vuelo: existe
/// para garantizar una emisión distinguible aun cuando los datos no cambien
/// (sin ella, refrescar a los mismos datos no emitiría y el spinner del
/// RefreshIndicator quedaría colgado). [uploadOutcome] es el resultado
/// TRANSITORIO del último lote de subida: se muestra sin tumbar la lista y no
/// es un estado terminal.
class MediaGalleryLoaded extends MediaGalleryState {
  const MediaGalleryLoaded({
    required this.items,
    required this.nextCursor,
    this.isLoadingMore = false,
    this.isUploading = false,
    this.isRefreshing = false,
    this.uploadOutcome,
    this.selectedRefs = const <String>{},
    this.isDeleting = false,
    this.uploadTotal = 0,
    this.uploadDone = 0,
    this.deleteTotal = 0,
    this.deleteDone = 0,
    this.loadMoreError,
    this.query = '',
    this.type,
  });

  final List<MediaAsset> items;
  final String nextCursor;
  final bool isLoadingMore;
  final bool isUploading;
  final bool isRefreshing;
  final MediaUploadOutcome? uploadOutcome;

  /// Progreso de una subida en lote: [uploadDone] de [uploadTotal] archivos
  /// completados. [uploadTotal] 0 ⇒ no hay subida en lote en curso. La UI
  /// muestra "Subiendo done/total" cuando total > 0.
  final int uploadTotal;
  final int uploadDone;

  /// Refs BARE seleccionados (modo selección múltiple). Vacío ⇒ no hay selección
  /// activa. [selectionMode] lo deriva.
  final Set<String> selectedRefs;

  /// Un borrado en lote en curso (bloquea acciones y muestra progreso).
  final bool isDeleting;

  /// Progreso del borrado en lote: [deleteDone] de [deleteTotal]. 0 ⇒ sin
  /// borrado en curso; la UI muestra "Borrando done de total…".
  final int deleteTotal;
  final int deleteDone;

  /// Error TRANSITORIO de paginación: la lista visible queda intacta y la UI
  /// ofrece reintentar al pie del grid. Se limpia al arrancar el retry.
  final MediaFailure? loadMoreError;

  /// Filtros activos de esta vista (espejo de los internos del bloc): le
  /// permiten a la UI distinguir "galería vacía" de "búsqueda sin resultados".
  final String query;
  final String? type;

  /// Hay filtros activos (búsqueda o tipo).
  bool get isFiltered => query.isNotEmpty || type != null;

  /// Hay más páginas sii el cursor no está vacío. Derivado, nunca un flag.
  bool get hasMore => nextCursor.isNotEmpty;

  /// El modo selección está activo sii hay al menos un ref seleccionado.
  /// Derivado: vaciar la selección sale del modo.
  bool get selectionMode => selectedRefs.isNotEmpty;

  MediaGalleryLoaded copyWith({
    List<MediaAsset>? items,
    String? nextCursor,
    bool? isLoadingMore,
    bool? isUploading,
    bool? isRefreshing,
    MediaUploadOutcome? uploadOutcome,
    bool clearUploadOutcome = false,
    Set<String>? selectedRefs,
    bool? isDeleting,
    int? uploadTotal,
    int? uploadDone,
    int? deleteTotal,
    int? deleteDone,
    MediaFailure? loadMoreError,
    bool clearLoadMoreError = false,
    String? query,
    String? type,
    bool clearType = false,
  }) => MediaGalleryLoaded(
    items: items ?? this.items,
    nextCursor: nextCursor ?? this.nextCursor,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isUploading: isUploading ?? this.isUploading,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    uploadOutcome: clearUploadOutcome
        ? null
        : (uploadOutcome ?? this.uploadOutcome),
    selectedRefs: selectedRefs ?? this.selectedRefs,
    isDeleting: isDeleting ?? this.isDeleting,
    uploadTotal: uploadTotal ?? this.uploadTotal,
    uploadDone: uploadDone ?? this.uploadDone,
    deleteTotal: deleteTotal ?? this.deleteTotal,
    deleteDone: deleteDone ?? this.deleteDone,
    loadMoreError: clearLoadMoreError
        ? null
        : (loadMoreError ?? this.loadMoreError),
    query: query ?? this.query,
    type: clearType ? null : (type ?? this.type),
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MediaGalleryLoaded) return false;
    if (other.nextCursor != nextCursor ||
        other.isLoadingMore != isLoadingMore ||
        other.isUploading != isUploading ||
        other.isRefreshing != isRefreshing ||
        other.uploadOutcome != uploadOutcome ||
        other.isDeleting != isDeleting ||
        other.uploadTotal != uploadTotal ||
        other.uploadDone != uploadDone ||
        other.deleteTotal != deleteTotal ||
        other.deleteDone != deleteDone ||
        other.loadMoreError != loadMoreError ||
        other.query != query ||
        other.type != type) {
      return false;
    }
    if (other.selectedRefs.length != selectedRefs.length ||
        !other.selectedRefs.containsAll(selectedRefs)) {
      return false;
    }
    if (other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(items),
    nextCursor,
    isLoadingMore,
    isUploading,
    isRefreshing,
    uploadOutcome,
    Object.hashAllUnordered(selectedRefs),
    isDeleting,
    uploadTotal,
    uploadDone,
    deleteTotal,
    deleteDone,
    loadMoreError,
    query,
    type,
  );
}

/// Falla de la PRIMERA carga (terminal: no hay lista que preservar). Las fallas
/// de load-more y de subida NO colapsan aquí — viven en [MediaGalleryLoaded]
/// para no tumbar el contenido ya visible.
class MediaGalleryFailed extends MediaGalleryState {
  const MediaGalleryFailed(this.failure);

  final MediaFailure failure;

  @override
  bool operator ==(Object other) =>
      other is MediaGalleryFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
