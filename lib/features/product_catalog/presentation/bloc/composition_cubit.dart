import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/composition_job.dart';
import '../../domain/failures/composition_failure.dart';
import '../../domain/repositories/composition_repository.dart';

enum CompositionListStatus { loading, loaded, error }

/// Estado de las composiciones de UN producto: la lista de jobs (recientes
/// primero, orden del backend) y el pulso de mutación en curso.
class CompositionState {
  const CompositionState({
    required this.status,
    required this.jobs,
    required this.failure,
    required this.mutating,
  });

  const CompositionState.loading()
    : status = CompositionListStatus.loading,
      jobs = const <CompositionJob>[],
      failure = null,
      mutating = false;

  final CompositionListStatus status;
  final List<CompositionJob> jobs;
  final CompositionFailure? failure;
  final bool mutating;

  /// Hay trabajo en vuelo: el cubit lo sigue con poll.
  bool get hasActiveJobs => jobs.any((j) => j.isActive);

  CompositionState copyWith({
    CompositionListStatus? status,
    List<CompositionJob>? jobs,
    CompositionFailure? failure,
    bool clearFailure = false,
    bool? mutating,
  }) => CompositionState(
    status: status ?? this.status,
    jobs: jobs ?? this.jobs,
    failure: clearFailure ? null : (failure ?? this.failure),
    mutating: mutating ?? this.mutating,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompositionState &&
        other.status == status &&
        other.failure == failure &&
        other.mutating == mutating &&
        _listEquals(other.jobs, jobs);
  }

  @override
  int get hashCode =>
      Object.hash(status, failure, mutating, Object.hashAll(jobs));
}

/// Flujo «Mejorar foto con IA» de un producto: listar sus jobs, encolar
/// composiciones y aceptar/descartar resultados.
///
/// Mientras haya jobs QUEUED/RUNNING re-consulta cada [_pollInterval] con un
/// timer ONE-SHOT que se re-agenda tras cada respuesta (nunca se encima un
/// fetch sobre otro); sin activos, o al cerrarse el cubit, no queda ningún
/// timer vivo. Un error transitorio del poll conserva la lista y reintenta;
/// solo el error de la carga inicial se muestra (con retry manual).
///
/// Las mutaciones devuelven la falla al llamador (el sheet decide el copy)
/// y en éxito recargan la lista: la vista nunca adivina el resultado de un
/// POST.
class CompositionCubit extends Cubit<CompositionState> {
  CompositionCubit(
    this._repo, {
    required String productId,
    Duration pollInterval = const Duration(seconds: 4),
  }) : _productId = productId,
       _pollInterval = pollInterval,
       super(const CompositionState.loading());

  final CompositionRepository _repo;
  final String _productId;
  final Duration _pollInterval;

  Timer? _poll;

  /// Secuencia de fetch: solo la respuesta del último load aplica (un poll
  /// lento no debe pisar la recarga de una mutación).
  int _seq = 0;

  Future<void> load() async {
    final seq = ++_seq;
    _poll?.cancel();
    try {
      final jobs = await _repo.listJobs(_productId);
      if (seq != _seq || isClosed) return;
      emit(
        state.copyWith(
          status: CompositionListStatus.loaded,
          jobs: jobs,
          clearFailure: true,
        ),
      );
    } on CompositionFailure catch (f) {
      if (seq != _seq || isClosed) return;
      if (state.status != CompositionListStatus.loaded) {
        emit(state.copyWith(status: CompositionListStatus.error, failure: f));
        return;
      }
      // Poll fallido con lista ya cargada: error transitorio; se conserva lo
      // conocido y el re-agendado de abajo reintenta.
    }
    _schedule();
  }

  Future<CompositionFailure?> compose({
    required String preset,
    bool premium = false,
  }) => _mutate(
    () =>
        _repo.compose(productId: _productId, preset: preset, premium: premium),
  );

  Future<CompositionFailure?> accept(String jobId) =>
      _mutate(() => _repo.accept(jobId));

  Future<CompositionFailure?> discard(String jobId) =>
      _mutate(() => _repo.discard(jobId));

  Future<CompositionFailure?> _mutate(Future<void> Function() op) async {
    if (state.mutating) return null;
    emit(state.copyWith(mutating: true));
    try {
      await op();
    } on CompositionFailure catch (f) {
      if (!isClosed) emit(state.copyWith(mutating: false));
      return f;
    }
    if (isClosed) return null;
    emit(state.copyWith(mutating: false));
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

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
