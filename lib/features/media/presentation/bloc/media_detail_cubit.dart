import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/media_asset.dart';
import '../../domain/failures/media_failure.dart';
import '../../domain/repositories/media_repository.dart';

/// Estado del detalle de un asset. [asset] es la verdad mostrada (el alias puede
/// actualizarse in-place). [busy] marca una mutación en vuelo; [deleting] afina
/// cuál (el feedback de carga vive en el control que la disparó, no en un velo
/// de página). [deleted] true tras un borrado exitoso ⇒ la página hace pop.
/// [error] es un fallo TRANSITORIO de la última mutación (se muestra sin tumbar
/// la vista).
class MediaDetailState {
  const MediaDetailState({
    required this.asset,
    this.busy = false,
    this.deleting = false,
    this.deleted = false,
    this.changed = false,
    this.error,
  });

  final MediaAsset asset;
  final bool busy;

  /// La mutación en vuelo es el borrado (subconjunto de [busy]).
  final bool deleting;

  final bool deleted;

  /// True si una mutación visible para la galería (renombrar alias) ocurrió. La
  /// página hace pop devolviendo este flag para que la galería se refresque. El
  /// borrado va por [deleted] (pop con true inmediato).
  final bool changed;
  final MediaFailure? error;

  MediaDetailState copyWith({
    MediaAsset? asset,
    bool? busy,
    bool? deleting,
    bool? deleted,
    bool? changed,
    MediaFailure? error,
    bool clearError = false,
  }) => MediaDetailState(
    asset: asset ?? this.asset,
    busy: busy ?? this.busy,
    deleting: deleting ?? this.deleting,
    deleted: deleted ?? this.deleted,
    changed: changed ?? this.changed,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  bool operator ==(Object other) =>
      other is MediaDetailState &&
      other.asset == asset &&
      other.busy == busy &&
      other.deleting == deleting &&
      other.deleted == deleted &&
      other.changed == changed &&
      other.error == error;

  @override
  int get hashCode =>
      Object.hash(asset, busy, deleting, deleted, changed, error);
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
    emit(state.copyWith(busy: true, deleting: true, clearError: true));
    try {
      await _repo.delete(state.asset.ref);
      emit(state.copyWith(busy: false, deleting: false, deleted: true));
    } on MediaFailure catch (f) {
      emit(state.copyWith(busy: false, deleting: false, error: f));
    }
  }

  /// Renombra el alias. El server devuelve el alias normalizado (trim), que se
  /// refleja in-place en el asset mostrado y marca `changed` para que la galería
  /// se refresque al volver. Un fallo viaja como error transitorio.
  Future<void> setAlias(String alias) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final normalized = await _repo.setAlias(state.asset.ref, alias);
      emit(
        state.copyWith(
          asset: state.asset.copyWith(alias: normalized),
          busy: false,
          changed: true,
        ),
      );
    } on MediaFailure catch (f) {
      emit(state.copyWith(busy: false, error: f));
    }
  }
}
