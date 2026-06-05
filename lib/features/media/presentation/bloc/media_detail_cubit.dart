import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/media_asset.dart';
import '../../domain/failures/media_failure.dart';
import '../../domain/repositories/media_repository.dart';

/// Estado del detalle de un asset. [asset] es la verdad mostrada (el alias puede
/// actualizarse in-place). [busy] marca una mutación en vuelo. [deleted] true
/// tras un borrado exitoso ⇒ la página hace pop. [error] es un fallo TRANSITORIO
/// de la última mutación (se muestra sin tumbar la vista).
class MediaDetailState {
  const MediaDetailState({
    required this.asset,
    this.busy = false,
    this.deleted = false,
    this.error,
  });

  final MediaAsset asset;
  final bool busy;
  final bool deleted;
  final MediaFailure? error;

  MediaDetailState copyWith({
    MediaAsset? asset,
    bool? busy,
    bool? deleted,
    MediaFailure? error,
    bool clearError = false,
  }) => MediaDetailState(
    asset: asset ?? this.asset,
    busy: busy ?? this.busy,
    deleted: deleted ?? this.deleted,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  bool operator ==(Object other) =>
      other is MediaDetailState &&
      other.asset == asset &&
      other.busy == busy &&
      other.deleted == deleted &&
      other.error == error;

  @override
  int get hashCode => Object.hash(asset, busy, deleted, error);
}

/// Cubit de las mutaciones del detalle de un asset (borrar; renombrar alias se
/// añade aparte). Page-scoped: nace con el asset abierto. Tras un borrado
/// exitoso emite `deleted:true` y la página hace pop devolviendo "cambió" para
/// que la galería se refresque.
class MediaDetailCubit extends Cubit<MediaDetailState> {
  MediaDetailCubit({required MediaRepository repo, required MediaAsset asset})
    : _repo = repo,
      super(MediaDetailState(asset: asset));

  final MediaRepository _repo;

  Future<void> deleteAsset() async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _repo.delete(state.asset.ref);
      emit(state.copyWith(busy: false, deleted: true));
    } on MediaFailure catch (f) {
      emit(state.copyWith(busy: false, error: f));
    }
  }
}
