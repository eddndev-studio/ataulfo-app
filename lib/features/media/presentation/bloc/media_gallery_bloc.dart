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
  }) : _repo = repo,
       _picker = picker,
       super(const MediaGalleryInitial()) {
    on<MediaGalleryLoadRequested>(_onLoad);
    on<MediaGalleryLoadMoreRequested>(_onLoadMore);
    on<MediaGalleryRefreshRequested>(_onRefresh);
    on<MediaGalleryUploadRequested>(_onUpload);
  }

  final MediaRepository _repo;
  final MediaFilePicker _picker;

  Future<void> _onLoad(
    MediaGalleryLoadRequested event,
    Emitter<MediaGalleryState> emit,
  ) async {}

  Future<void> _onLoadMore(
    MediaGalleryLoadMoreRequested event,
    Emitter<MediaGalleryState> emit,
  ) async {}

  Future<void> _onRefresh(
    MediaGalleryRefreshRequested event,
    Emitter<MediaGalleryState> emit,
  ) async {}

  Future<void> _onUpload(
    MediaGalleryUploadRequested event,
    Emitter<MediaGalleryState> emit,
  ) async {}
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
/// subida en curso. [uploadError] es un error TRANSITORIO de la última subida:
/// se muestra sin tumbar la lista y no es un estado terminal.
class MediaGalleryLoaded extends MediaGalleryState {
  const MediaGalleryLoaded({
    required this.items,
    required this.nextCursor,
    this.isLoadingMore = false,
    this.isUploading = false,
    this.uploadError,
  });

  final List<MediaAsset> items;
  final String nextCursor;
  final bool isLoadingMore;
  final bool isUploading;
  final MediaFailure? uploadError;

  /// Hay más páginas sii el cursor no está vacío. Derivado, nunca un flag.
  bool get hasMore => nextCursor.isNotEmpty;

  MediaGalleryLoaded copyWith({
    List<MediaAsset>? items,
    String? nextCursor,
    bool? isLoadingMore,
    bool? isUploading,
    MediaFailure? uploadError,
    bool clearUploadError = false,
  }) => MediaGalleryLoaded(
    items: items ?? this.items,
    nextCursor: nextCursor ?? this.nextCursor,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isUploading: isUploading ?? this.isUploading,
    uploadError: clearUploadError ? null : (uploadError ?? this.uploadError),
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MediaGalleryLoaded) return false;
    if (other.nextCursor != nextCursor ||
        other.isLoadingMore != isLoadingMore ||
        other.isUploading != isUploading ||
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
