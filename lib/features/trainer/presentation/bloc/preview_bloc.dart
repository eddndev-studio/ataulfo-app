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

/// Emulador del bot. El turno es síncrono (el POST devuelve los items
/// completos), pero el hilo los REVELA item por item con la cadencia de un
/// envío real: el user inmediato, cada envío del bot con un compás corto y
/// los pasos de flujo simulados con SU retraso configurado (`delayMs`).
class PreviewBloc extends Bloc<PreviewEvent, PreviewState> {
  PreviewBloc({
    required PreviewRepository repo,
    required String templateId,
    Future<void> Function(Duration)? pace,
  }) : _repo = repo,
       _templateId = templateId,
       _pace = pace ?? ((d) => Future<void>.delayed(d)),
       super(const PreviewLoading()) {
    on<PreviewStarted>(_onStarted);
    on<PreviewMessageSent>(_onMessageSent);
    on<PreviewResetRequested>(_onReset);
  }

  final PreviewRepository _repo;
  final String _templateId;

  /// Espera entre revelados. Inyectable: los tests verifican cadencia sin
  /// dormir relojes reales.
  final Future<void> Function(Duration) _pace;

  /// Compás default entre envíos del bot sin retraso propio: suficiente para
  /// que dos burbujas seguidas se LEAN como dos envíos, sin estorbar.
  static const Duration _stagger = Duration(milliseconds: 450);

  /// Techo del retraso reproducido: un paso con minutos de delay haría
  /// inusable el demo; 6s bastan para SENTIR la cadencia configurada.
  static const Duration _maxStepDelay = Duration(seconds: 6);

  /// Espera previa a revelar [it]: el user es inmediato (ya estaba pintado
  /// como optimista); un paso con `delayMs` usa su retraso (clampeado); el
  /// resto lleva el compás default.
  Duration _waitFor(PreviewItem it) {
    if (it.isUser) return Duration.zero;
    if (it.delayMs > 0) {
      final d = Duration(milliseconds: it.delayMs);
      return d > _maxStepDelay ? _maxStepDelay : d;
    }
    return _stagger;
  }

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
    // Optimista: la burbuja del usuario se pinta al ENVIAR. El turno del
    // server la trae de vuelta (el sandbox graba el item user primero), así
    // que al resolver se reemplaza desde `current.items` — sin duplicarla.
    final optimistic = PreviewItem(
      kind: 'user',
      text: event.content,
      at: DateTime.now().toUtc(),
    );
    emit(
      PreviewLoaded(
        items: <PreviewItem>[...current.items, optimistic],
        sending: true,
      ),
    );
    try {
      final turn = await _repo.sendMessage(
        templateId: _templateId,
        content: event.content,
      );
      // Revelado paceado: el turno se pinta item por item (typing encendido
      // entre revelados); el último apaga el typing. El acumulador arranca
      // de `current.items` (pre-optimista): el user del server reemplaza al
      // optimista sin duplicarlo.
      var acc = current.items;
      for (var i = 0; i < turn.items.length; i++) {
        final wait = _waitFor(turn.items[i]);
        if (wait > Duration.zero) {
          await _pace(wait);
        }
        if (isClosed || emit.isDone) return;
        acc = <PreviewItem>[...acc, turn.items[i]];
        emit(PreviewLoaded(items: acc, sending: i < turn.items.length - 1));
      }
      if (turn.items.isEmpty) {
        emit(PreviewLoaded(items: acc, sending: false));
      }
    } on TrainerFailure catch (f) {
      // El sandbox descarta el turno fallido completo (incluido el item
      // user): revertir el optimista espeja la verdad del server.
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
