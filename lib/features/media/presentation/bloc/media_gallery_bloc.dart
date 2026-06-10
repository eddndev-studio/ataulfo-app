import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/media_asset.dart';
import '../../domain/failures/media_failure.dart';
import '../../domain/repositories/media_file_picker.dart';
import '../../domain/repositories/media_repository.dart';

/// Bloc de la galería de media de la organización. Es la máquina de estados de
/// la paginación load-more: el scroll de la página es un disparador delgado, la
/// verdad (qué páginas hay, si se está cargando otra) vive aquí.
///
/// `hasMore` NO es un flag: se DERIVA de `nextCursor.isNotEmpty` en [MediaGalleryLoaded]
/// para que no pueda desincronizarse del cursor real.
class MediaGalleryBloc extends Bloc<MediaGalleryEvent, MediaGalleryState> {
  MediaGalleryBloc({
    required MediaRepository repo,
    required MediaFilePicker picker,
    String? type,
  }) : _repo = repo,
       _picker = picker,
       _type = type,
       super(const MediaGalleryInitial()) {
    on<MediaGalleryLoadRequested>(_onLoad);
    on<MediaGalleryLoadMoreRequested>(_onLoadMore);
    on<MediaGalleryRefreshRequested>(_onRefresh);
    on<MediaGalleryUploadRequested>(_onUpload);
    on<MediaGallerySearchChanged>(_onSearchChanged);
    on<MediaGalleryTypeChanged>(_onTypeChanged);
    on<MediaGallerySelectionToggled>(_onSelectionToggled);
    on<MediaGallerySelectionCleared>(_onSelectionCleared);
    on<MediaGalleryDeleteSelectedRequested>(_onDeleteSelected);
  }

  final MediaRepository _repo;
  final MediaFilePicker _picker;

  /// Término de búsqueda activo (filename o alias). Vacío ⇒ sin búsqueda. Se
  /// aplica a TODAS las páginas (primera, load-more, refresh, re-list tras subir)
  /// para que la paginación no mezcle resultados filtrados y sin filtrar. La UI
  /// lo cambia (debounced) vía [MediaGallerySearchChanged].
  String _query = '';

  /// El `q` que viaja al repo: null cuando no hay búsqueda (vacío), para que la
  /// query omita `?q=` y el caching memoice la primera página sin filtro.
  String? get _queryParam => _query.isEmpty ? null : _query;

  /// Familia de content-type por la que se filtra el catálogo (image|video|
  /// audio|document). null ⇒ galería completa. Se inicializa al construir: en el
  /// picker queda fijo (el tipo del paso de flujo; la UI no muestra tabs ahí) y
  /// en browse arranca null y lo cambian las tabs vía [MediaGalleryTypeChanged].
  /// Se aplica a TODAS las páginas para que la paginación no mezcle familias.
  String? _type;

  Future<void> _onLoad(
    MediaGalleryLoadRequested event,
    Emitter<MediaGalleryState> emit,
  ) async {
    emit(const MediaGalleryLoading());
    await _fetchFirstPage(emit);
  }

  Future<void> _onLoadMore(
    MediaGalleryLoadMoreRequested event,
    Emitter<MediaGalleryState> emit,
  ) async {
    final current = state;
    // Guardas: sólo paginamos desde Loaded, sólo si hay más páginas y no hay
    // ya una en vuelo. La de concurrencia depende de emitir `isLoadingMore`
    // ANTES del primer await (abajo): así un segundo LoadMore encolado lee el
    // estado ya actualizado y cae en este `return` sin disparar otro fetch.
    if (current is! MediaGalleryLoaded ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true, clearLoadMoreError: true));
    try {
      final page = await _repo.listAssets(
        cursor: current.nextCursor,
        type: _type,
        q: _queryParam,
      );
      // Append sin duplicar: la página nueva se concatena al final.
      emit(
        current.copyWith(
          items: <MediaAsset>[...current.items, ...page.assets],
          nextCursor: page.nextCursor,
          isLoadingMore: false,
          // `current` es el snapshot pre-emisión: limpia un error previo que
          // copyWith arrastraría desde un intento fallido anterior.
          clearLoadMoreError: true,
        ),
      );
    } on MediaFailure catch (f) {
      // Un fallo de paginación no tumba la lista visible: revertimos el flag,
      // dejamos items/cursor intactos y exponemos el error para que la UI
      // ofrezca reintentar al pie del grid.
      emit(current.copyWith(isLoadingMore: false, loadMoreError: f));
    }
  }

  Future<void> _onRefresh(
    MediaGalleryRefreshRequested event,
    Emitter<MediaGalleryState> emit,
  ) async {
    final current = state;
    // Desde Loaded recargamos la primera página SIN pasar por Loading: la lista
    // visible se mantiene mientras el RefreshIndicator gira. La señal transitoria
    // `isRefreshing:true` garantiza una emisión distinguible aunque la página
    // nueva iguale a la actual, para que el `firstWhere` del pull-to-refresh no
    // quede colgado. Desde otro estado, es una primera carga normal (Loading).
    if (current is MediaGalleryLoaded) {
      emit(current.copyWith(isRefreshing: true));
    } else {
      emit(const MediaGalleryLoading());
    }
    // Forzar red: descartamos cualquier verdad cacheada antes de recargar. El
    // repo no puede inferir que esta lectura es un refresh (misma firma que la
    // carga de entrada que SÍ debe servir cache), así que el bloc lo señala.
    _repo.invalidate();
    await _fetchFirstPage(emit);
  }

  Future<void> _onUpload(
    MediaGalleryUploadRequested event,
    Emitter<MediaGalleryState> emit,
  ) async {
    final picked = await _picker.pickMultiple();
    // Cancelación / sin archivos: no-op.
    if (picked.isEmpty) return;

    final current = state;
    final base = current is MediaGalleryLoaded
        ? current
        : const MediaGalleryLoaded(items: <MediaAsset>[], nextCursor: '');
    final total = picked.length;
    emit(
      base.copyWith(
        isUploading: true,
        uploadTotal: total,
        uploadDone: 0,
        clearUploadError: true,
      ),
    );
    // Subida secuencial con progreso. Un archivo que falla NO aborta el lote:
    // guardamos el último error y seguimos; el re-list final muestra la verdad
    // (lo que sí subió) y el error transitorio dispara el snackbar.
    MediaFailure? lastError;
    var done = 0;
    for (final p in picked) {
      try {
        await _repo.upload(bytes: p.bytes, filename: p.filename);
      } on MediaFailure catch (f) {
        lastError = f;
      }
      done++;
      emit(
        base.copyWith(
          isUploading: true,
          uploadTotal: total,
          uploadDone: done,
          clearUploadError: true,
        ),
      );
    }
    // Re-listamos para mostrar los assets con la verdad del servidor (no
    // fabricamos MediaAsset desde UploadedMedia). Respetamos familia + búsqueda.
    try {
      final page = await _repo.listAssets(type: _type, q: _queryParam);
      emit(
        MediaGalleryLoaded(
          items: page.assets,
          nextCursor: page.nextCursor,
          uploadError: lastError,
        ),
      );
    } on MediaFailure catch (f) {
      emit(
        base.copyWith(
          isUploading: false,
          uploadTotal: 0,
          uploadDone: 0,
          uploadError: lastError ?? f,
        ),
      );
    }
  }

  /// Carga la primera página y emite Loaded; un `MediaFailure` colapsa a Failed
  /// (terminal: no hay lista previa que preservar en la carga inicial). Aplica
  /// el filtro de familia y la búsqueda activa.
  Future<void> _fetchFirstPage(Emitter<MediaGalleryState> emit) async {
    try {
      final page = await _repo.listAssets(type: _type, q: _queryParam);
      emit(
        MediaGalleryLoaded(
          items: page.assets,
          nextCursor: page.nextCursor,
          query: _query,
          type: _type,
        ),
      );
    } on MediaFailure catch (f) {
      emit(MediaGalleryFailed(f));
    }
  }

  /// Cambia el término de búsqueda y recarga la primera página. Guard de
  /// no-cambio: un término igual al activo no recarga. Guard de obsolescencia:
  /// si llega un término más nuevo mientras este fetch estaba en vuelo, su
  /// resultado se descarta (last-search-wins) — necesario porque el handler es
  /// concurrente y la red puede reordenar respuestas. La UI hace debounce.
  Future<void> _onSearchChanged(
    MediaGallerySearchChanged event,
    Emitter<MediaGalleryState> emit,
  ) async {
    final q = event.query.trim();
    if (q == _query) return;
    _query = q;
    emit(const MediaGalleryLoading());
    try {
      final page = await _repo.listAssets(type: _type, q: _queryParam);
      if (_query != q) return; // un search más nuevo ganó
      emit(
        MediaGalleryLoaded(
          items: page.assets,
          nextCursor: page.nextCursor,
          query: _query,
          type: _type,
        ),
      );
    } on MediaFailure catch (f) {
      if (_query != q) return;
      emit(MediaGalleryFailed(f));
    }
  }

  /// Cambia la familia filtrada (tabs de browse) y recarga la primera página,
  /// preservando la búsqueda activa. Guards de no-cambio y de obsolescencia,
  /// como la búsqueda (taps rápidos podrían reordenar respuestas).
  Future<void> _onTypeChanged(
    MediaGalleryTypeChanged event,
    Emitter<MediaGalleryState> emit,
  ) async {
    if (event.type == _type) return;
    _type = event.type;
    emit(const MediaGalleryLoading());
    try {
      final page = await _repo.listAssets(type: event.type, q: _queryParam);
      if (_type != event.type) return; // un cambio de tipo más nuevo ganó
      emit(
        MediaGalleryLoaded(
          items: page.assets,
          nextCursor: page.nextCursor,
          query: _query,
          type: _type,
        ),
      );
    } on MediaFailure catch (f) {
      if (_type != event.type) return;
      emit(MediaGalleryFailed(f));
    }
  }

  /// Alterna un ref en la selección (long-press entra al modo; tap alterna). No
  /// toca la red. Bloqueado durante un borrado en lote.
  void _onSelectionToggled(
    MediaGallerySelectionToggled event,
    Emitter<MediaGalleryState> emit,
  ) {
    final current = state;
    if (current is! MediaGalleryLoaded || current.isDeleting) return;
    final next = Set<String>.of(current.selectedRefs);
    if (!next.add(event.ref)) next.remove(event.ref);
    emit(current.copyWith(selectedRefs: next));
  }

  /// Vacía la selección (sale del modo selección).
  void _onSelectionCleared(
    MediaGallerySelectionCleared event,
    Emitter<MediaGalleryState> emit,
  ) {
    final current = state;
    if (current is! MediaGalleryLoaded) return;
    emit(current.copyWith(selectedRefs: const <String>{}));
  }

  /// Borra en lote los refs seleccionados. El endpoint borra 1 ref/llamada, así
  /// que iteramos. Los fallos por-ref no abortan el lote: tras intentar todos,
  /// invalidamos y re-listamos — la lista re-traída ES la verdad (lo que no se
  /// borró sigue ahí), y la selección se limpia. Si el re-list falla, conserva
  /// la lista visible (no colapsa a Failed) y sale del modo.
  Future<void> _onDeleteSelected(
    MediaGalleryDeleteSelectedRequested event,
    Emitter<MediaGalleryState> emit,
  ) async {
    final current = state;
    if (current is! MediaGalleryLoaded ||
        current.selectedRefs.isEmpty ||
        current.isDeleting) {
      return;
    }
    final total = current.selectedRefs.length;
    var done = 0;
    emit(current.copyWith(isDeleting: true, deleteTotal: total, deleteDone: 0));
    for (final ref in current.selectedRefs) {
      try {
        await _repo.delete(ref);
      } on MediaFailure {
        // Tolerante: el re-list reflejará qué sobrevivió.
      }
      done += 1;
      emit(
        current.copyWith(
          isDeleting: true,
          deleteTotal: total,
          deleteDone: done,
        ),
      );
    }
    _repo.invalidate();
    try {
      final page = await _repo.listAssets(type: _type, q: _queryParam);
      emit(
        MediaGalleryLoaded(
          items: page.assets,
          nextCursor: page.nextCursor,
          query: _query,
          type: _type,
        ),
      );
    } on MediaFailure {
      emit(current.copyWith(isDeleting: false, selectedRefs: const <String>{}));
    }
  }
}

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

// States --------------------------------------------------------------------

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
/// RefreshIndicator quedaría colgado). [uploadError] es un error TRANSITORIO de
/// la última subida: se muestra sin tumbar la lista y no es un estado terminal.
class MediaGalleryLoaded extends MediaGalleryState {
  const MediaGalleryLoaded({
    required this.items,
    required this.nextCursor,
    this.isLoadingMore = false,
    this.isUploading = false,
    this.isRefreshing = false,
    this.uploadError,
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
  final MediaFailure? uploadError;

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
    MediaFailure? uploadError,
    bool clearUploadError = false,
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
    uploadError: clearUploadError ? null : (uploadError ?? this.uploadError),
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
        other.uploadError != uploadError ||
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
    uploadError,
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
