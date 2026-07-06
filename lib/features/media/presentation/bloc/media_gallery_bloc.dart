import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/media_asset.dart';
import '../../domain/failures/media_failure.dart';
import '../../domain/repositories/media_file_picker.dart';
import '../../domain/repositories/media_repository.dart';

part 'media_gallery_event.dart';
part 'media_gallery_state.dart';

// Nota (~410 líneas): este archivo contiene SOLO la máquina de estados de la
// galería — paginación, subida, filtros, selección y borrado son transiciones
// del mismo estado y se guardan entre sí, así que partirla la rompería.
// Events y states ya viven en los parts hermanos.

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
       _fixedType = type,
       super(const MediaGalleryInitial()) {
    on<MediaGalleryLoadRequested>(_onLoad);
    on<MediaGalleryLoadMoreRequested>(_onLoadMore);
    on<MediaGalleryRefreshRequested>(_onRefresh);
    on<MediaGalleryUploadRequested>(_onUpload);
    on<MediaGallerySearchChanged>(_onSearchChanged);
    on<MediaGalleryTypeChanged>(_onTypeChanged);
    on<MediaGalleryFiltersCleared>(_onFiltersCleared);
    on<MediaGallerySelectionToggled>(_onSelectionToggled);
    on<MediaGallerySelectionCleared>(_onSelectionCleared);
    on<MediaGalleryDeleteSelectedRequested>(_onDeleteSelected);
    on<MediaGalleryDeleteCancelRequested>(_onDeleteCancel);
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

  /// Familia FIJA con la que se construyó el bloc (picker abierto por un paso
  /// de flujo con tipo). Limpiar filtros vuelve aquí, nunca más abajo: el tipo
  /// del paso es una restricción del caller, no un filtro del usuario. null ⇒
  /// no hay restricción (browse o picker libre) y limpiar deja la galería
  /// completa.
  final String? _fixedType;

  /// Cancelación cooperativa del borrado en lote: la bandera se arma con
  /// [MediaGalleryDeleteCancelRequested] (handler concurrente) y el loop de
  /// deletes la consulta antes de cada llamada. Se desarma al arrancar un lote.
  bool _deleteCancelRequested = false;

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
        clearUploadOutcome: true,
      ),
    );
    // Subida secuencial con progreso. Un archivo que falla NO aborta el lote:
    // acumulamos cuántos fallaron (y el último error como muestra) y seguimos;
    // el re-list final muestra la verdad (lo que sí subió) y el outcome
    // transitorio alimenta el feedback de la UI con el conteo real.
    MediaFailure? lastError;
    var failed = 0;
    final uploadedRefs = <String>[];
    var done = 0;
    for (final p in picked) {
      try {
        final uploaded = await _repo.upload(
          bytes: p.bytes,
          filename: p.filename,
        );
        uploadedRefs.add(uploaded.ref);
      } on MediaFailure catch (f) {
        lastError = f;
        failed++;
      }
      done++;
      emit(
        base.copyWith(
          isUploading: true,
          uploadTotal: total,
          uploadDone: done,
          clearUploadOutcome: true,
        ),
      );
    }
    // Re-listamos para mostrar los assets con la verdad del servidor (no
    // fabricamos MediaAsset desde UploadedMedia). Respetamos familia + búsqueda;
    // si algún ref recién subido NO aparece en la primera página re-traída con
    // filtros activos, quedó oculto por el filtro y el outcome lo señala para
    // que la UI ofrezca "Ver todo" en vez de desaparecerlo en silencio.
    try {
      final page = await _repo.listAssets(type: _type, q: _queryParam);
      final visibleRefs = <String>{for (final a in page.assets) a.ref};
      final hiddenByFilter =
          (_query.isNotEmpty || _type != null) &&
          uploadedRefs.any((ref) => !visibleRefs.contains(ref));
      emit(
        MediaGalleryLoaded(
          items: page.assets,
          nextCursor: page.nextCursor,
          query: _query,
          type: _type,
          uploadOutcome: MediaUploadOutcome(
            total: total,
            failed: failed,
            lastError: lastError,
            hiddenByFilter: hiddenByFilter,
          ),
        ),
      );
    } on MediaFailure catch (f) {
      emit(
        base.copyWith(
          isUploading: false,
          uploadTotal: 0,
          uploadDone: 0,
          uploadOutcome: MediaUploadOutcome(
            total: total,
            failed: failed,
            lastError: lastError ?? f,
          ),
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

  /// Limpia búsqueda y familia en UNA sola recarga. La familia vuelve al
  /// [_fixedType] del constructor (restricción del caller en el picker), no
  /// necesariamente a null. No-op si no hay nada que limpiar.
  Future<void> _onFiltersCleared(
    MediaGalleryFiltersCleared event,
    Emitter<MediaGalleryState> emit,
  ) async {
    if (_query.isEmpty && _type == _fixedType) return;
    _query = '';
    _type = _fixedType;
    emit(const MediaGalleryLoading());
    await _fetchFirstPage(emit);
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
    _deleteCancelRequested = false;
    emit(current.copyWith(isDeleting: true, deleteTotal: total, deleteDone: 0));
    for (final ref in current.selectedRefs) {
      // Cancelación cooperativa: no se emiten MÁS deletes (el que está en
      // vuelo ya salió); el re-list final refleja lo que alcanzó a borrarse.
      if (_deleteCancelRequested) break;
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

  /// Arma la bandera de cancelación del lote de borrado en curso. Handler
  /// aparte (concurrente) para que llegue MIENTRAS [_onDeleteSelected] espera
  /// un delete en vuelo. Sin lote en curso es inocuo: la bandera se desarma al
  /// arrancar el siguiente.
  void _onDeleteCancel(
    MediaGalleryDeleteCancelRequested event,
    Emitter<MediaGalleryState> emit,
  ) {
    _deleteCancelRequested = true;
  }
}
