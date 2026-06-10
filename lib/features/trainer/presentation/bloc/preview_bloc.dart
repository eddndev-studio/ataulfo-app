import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/preview_item.dart';
import '../../domain/failures/trainer_failure.dart';
import '../../domain/repositories/trainer_repositories.dart';

sealed class PreviewEvent {
  const PreviewEvent();
}

final class PreviewStarted extends PreviewEvent {
  const PreviewStarted();
}

final class PreviewMessageSent extends PreviewEvent {
  const PreviewMessageSent(this.content);

  final String content;
}

final class PreviewResetRequested extends PreviewEvent {
  const PreviewResetRequested();
}

sealed class PreviewState {
  const PreviewState();
}

final class PreviewLoading extends PreviewState {
  const PreviewLoading();

  @override
  bool operator ==(Object other) => other is PreviewLoading;

  @override
  int get hashCode => (PreviewLoading).hashCode;
}

final class PreviewLoaded extends PreviewState {
  const PreviewLoaded({
    required this.items,
    required this.sending,
    this.failure,
  });

  final List<PreviewItem> items;
  final bool sending;

  /// Fallo del último turno (503 sandbox sin cablear, 502 motor...); el
  /// transcript previo sigue visible.
  final TrainerFailure? failure;

  @override
  bool operator ==(Object other) =>
      other is PreviewLoaded &&
      listEquals(other.items, items) &&
      other.sending == sending &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(Object.hashAll(items), sending, failure);
}

/// Emulador del bot. El turno es síncrono: el POST devuelve los items
/// nuevos (burbujas + chips de acciones grabadas) y se ANEXAN al hilo.
class PreviewBloc extends Bloc<PreviewEvent, PreviewState> {
  PreviewBloc({required PreviewRepository repo, required String templateId})
    : _repo = repo,
      _templateId = templateId,
      super(const PreviewLoading()) {
    on<PreviewStarted>(_onStarted);
    on<PreviewMessageSent>(_onMessageSent);
    on<PreviewResetRequested>(_onReset);
  }

  final PreviewRepository _repo;
  final String _templateId;

  Future<void> _onStarted(
    PreviewStarted event,
    Emitter<PreviewState> emit,
  ) async {
    emit(const PreviewLoading());
    try {
      final items = await _repo.transcript(templateId: _templateId);
      emit(PreviewLoaded(items: items, sending: false));
    } on TrainerFailure {
      // Sesión inexistente/expirada o transporte: el demo arranca vacío
      // (no hay nada que rehidratar) — el primer turno reporta si algo
      // sigue mal.
      emit(const PreviewLoaded(items: <PreviewItem>[], sending: false));
    }
  }

  Future<void> _onMessageSent(
    PreviewMessageSent event,
    Emitter<PreviewState> emit,
  ) async {
    final current = state;
    if (current is! PreviewLoaded || current.sending) return;
    emit(PreviewLoaded(items: current.items, sending: true));
    try {
      final turn = await _repo.sendMessage(
        templateId: _templateId,
        content: event.content,
      );
      emit(
        PreviewLoaded(
          items: <PreviewItem>[...current.items, ...turn.items],
          sending: false,
        ),
      );
    } on TrainerFailure catch (f) {
      emit(PreviewLoaded(items: current.items, sending: false, failure: f));
    }
  }

  Future<void> _onReset(
    PreviewResetRequested event,
    Emitter<PreviewState> emit,
  ) async {
    final current = state;
    if (current is! PreviewLoaded) return;
    try {
      await _repo.reset(templateId: _templateId);
      emit(const PreviewLoaded(items: <PreviewItem>[], sending: false));
    } on TrainerFailure catch (f) {
      emit(PreviewLoaded(items: current.items, sending: false, failure: f));
    }
  }
}
