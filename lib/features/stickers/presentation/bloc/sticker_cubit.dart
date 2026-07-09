import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/sticker_job.dart';
import '../../domain/failures/sticker_failure.dart';
import '../../domain/repositories/sticker_repository.dart';

enum StickerListStatus { loading, loaded, error }

/// Estado de los stickers de la org: la lista de jobs (recientes primero) y el
/// pulso de generación en curso.
class StickerState {
  const StickerState({
    required this.status,
    required this.jobs,
    required this.failure,
    required this.generating,
  });

  const StickerState.loading()
    : status = StickerListStatus.loading,
      jobs = const <StickerJob>[],
      failure = null,
      generating = false;

  final StickerListStatus status;
  final List<StickerJob> jobs;
  final StickerFailure? failure;
  final bool generating;

  /// Stickers usables (DONE con ref), recientes primero: lo que ofrece el
  /// selector del chat.
  List<StickerJob> get ready =>
      jobs.where((j) => j.isReady).toList(growable: false);

  /// Hay trabajo en vuelo: el cubit lo sigue con poll.
  bool get hasActiveJobs => jobs.any((j) => j.isActive);

  StickerState copyWith({
    StickerListStatus? status,
    List<StickerJob>? jobs,
    StickerFailure? failure,
    bool clearFailure = false,
    bool? generating,
  }) => StickerState(
    status: status ?? this.status,
    jobs: jobs ?? this.jobs,
    failure: clearFailure ? null : (failure ?? this.failure),
    generating: generating ?? this.generating,
  );
}

/// Lista, sigue y genera los stickers de la org. Mientras haya jobs QUEUED/
/// RUNNING re-consulta cada [_pollInterval] con un timer ONE-SHOT re-agendado
/// tras cada respuesta (nunca encima fetches; sin activos o al cerrarse no
/// queda timer vivo). Un error transitorio del poll conserva la lista; solo el
/// error de la carga inicial se muestra. `generate` devuelve la falla al
/// llamador (el sheet decide el copy) y en éxito recarga.
class StickerCubit extends Cubit<StickerState> {
  StickerCubit(this._repo, {Duration pollInterval = const Duration(seconds: 4)})
    : _pollInterval = pollInterval,
      super(const StickerState.loading());

  final StickerRepository _repo;
  final Duration _pollInterval;

  Timer? _poll;
  int _seq = 0;

  Future<void> load() async {
    final seq = ++_seq;
    _poll?.cancel();
    try {
      final jobs = await _repo.list();
      if (seq != _seq || isClosed) return;
      emit(
        state.copyWith(
          status: StickerListStatus.loaded,
          jobs: jobs,
          clearFailure: true,
        ),
      );
    } on StickerFailure catch (f) {
      if (seq != _seq || isClosed) return;
      if (state.status != StickerListStatus.loaded) {
        emit(state.copyWith(status: StickerListStatus.error, failure: f));
        return;
      }
      // Poll fallido con lista ya cargada: error transitorio; se conserva lo
      // conocido y el re-agendado de abajo reintenta.
    }
    _schedule();
  }

  /// Encola un sticker; éxito ⇒ recarga (aparecerá en la lista y hará poll);
  /// falla ⇒ se devuelve al llamador.
  Future<StickerFailure?> generate(String motif) async {
    if (state.generating) return null;
    emit(state.copyWith(generating: true));
    try {
      await _repo.generate(motif);
    } on StickerFailure catch (f) {
      if (!isClosed) emit(state.copyWith(generating: false));
      return f;
    }
    if (isClosed) return null;
    emit(state.copyWith(generating: false));
    await load();
    return null;
  }

  void _schedule() {
    _poll?.cancel();
    if (isClosed || !state.hasActiveJobs) return;
    _poll = Timer(_pollInterval, () => unawaited(load()));
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}
