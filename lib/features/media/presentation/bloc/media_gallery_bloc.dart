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
    emit(current.copyWith(isLoadingMore: true));
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
        ),
      );
    } on MediaFailure {
      // Un fallo de paginación no tumba la lista visible: revertimos el flag y
      // dejamos items/cursor intactos para que el usuario pueda reintentar.
      emit(current.copyWith(isLoadingMore: false));
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
    final picked = await _picker.pick();
    // Cancelación: no-op. No subimos ni tocamos el estado.
    if (picked == null) return;

    final current = state;
    final base = current is MediaGalleryLoaded
        ? current
        : const MediaGalleryLoaded(items: <MediaAsset>[], nextCursor: '');
    emit(base.copyWith(isUploading: true, clearUploadError: true));
    try {
      await _repo.upload(bytes: picked.bytes, filename: picked.filename);
      // No fabricamos un MediaAsset desde el UploadedMedia (sólo trae ref+url,
      // sin metadata): re-listamos para mostrar el asset con la verdad del
      // servidor. Respetamos el filtro de familia y la búsqueda activa para no
      // traer ajenos al picker ni romper el filtro visible.
      final page = await _repo.listAssets(type: _type, q: _queryParam);
      emit(MediaGalleryLoaded(items: page.assets, nextCursor: page.nextCursor));
    } on MediaFailure catch (f) {
      // El fallo de subida NO colapsa a Failed (eso vaciaría la galería):
      // viaja como error transitorio sobre el Loaded actual; la UI lo muestra
      // (snackbar) y la lista sigue intacta.
      emit(base.copyWith(isUploading: false, uploadError: f));
    }
  }

  /// Carga la primera página y emite Loaded; un `MediaFailure` colapsa a Failed
  /// (terminal: no hay lista previa que preservar en la carga inicial). Aplica
  /// el filtro de familia y la búsqueda activa.
  Future<void> _fetchFirstPage(Emitter<MediaGalleryState> emit) async {
    try {
      final page = await _repo.listAssets(type: _type, q: _queryParam);
      emit(MediaGalleryLoaded(items: page.assets, nextCursor: page.nextCursor));
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
      emit(MediaGalleryLoaded(items: page.assets, nextCursor: page.nextCursor));
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
      emit(MediaGalleryLoaded(items: page.assets, nextCursor: page.nextCursor));
    } on MediaFailure catch (f) {
      if (_type != event.type) return;
      emit(MediaGalleryFailed(f));
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
  });

  final List<MediaAsset> items;
  final String nextCursor;
  final bool isLoadingMore;
  final bool isUploading;
  final bool isRefreshing;
  final MediaFailure? uploadError;

  /// Hay más páginas sii el cursor no está vacío. Derivado, nunca un flag.
  bool get hasMore => nextCursor.isNotEmpty;

  MediaGalleryLoaded copyWith({
    List<MediaAsset>? items,
    String? nextCursor,
    bool? isLoadingMore,
    bool? isUploading,
    bool? isRefreshing,
    MediaFailure? uploadError,
    bool clearUploadError = false,
  }) => MediaGalleryLoaded(
    items: items ?? this.items,
    nextCursor: nextCursor ?? this.nextCursor,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isUploading: isUploading ?? this.isUploading,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    uploadError: clearUploadError ? null : (uploadError ?? this.uploadError),
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MediaGalleryLoaded) return false;
    if (other.nextCursor != nextCursor ||
        other.isLoadingMore != isLoadingMore ||
        other.isUploading != isUploading ||
        other.isRefreshing != isRefreshing ||
        other.uploadError != uploadError) {
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
