// Nota de tamaño (>400 LOC): eventos+estado+bloc del preview viven juntos
// (mismo patrón que trainer_chat_bloc); separar los eventos del handler que
// los consume dispersaría un protocolo pequeño y cerrado.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/attachment_limits.dart';
import '../../domain/entities/preview_attachment.dart';
import '../../domain/entities/preview_item.dart';
import '../../domain/failures/trainer_failure.dart';
import '../../../media/domain/repositories/media_file_picker.dart';
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

/// El operador adjunta un archivo al próximo turno del demo (bytes en
/// memoria del cliente; viajan base64 con el send).
final class PreviewAttachRequested extends PreviewEvent {
  const PreviewAttachRequested();
}

/// Quita un adjunto pendiente por nombre.
final class PreviewAttachmentRemoved extends PreviewEvent {
  const PreviewAttachmentRemoved(this.name);

  final String name;
}

final class PreviewResetRequested extends PreviewEvent {
  const PreviewResetRequested();
}

/// El poll de la ventana de acumulación encontró el flush aterrizado:
/// `transcript` es la verdad completa del server. Interno al bloc — el poll
/// corre fuera del handler para no bloquear la cola de eventos (el operador
/// puede seguir mandando mensajes durante la ventana).
final class _PreviewFlushArrived extends PreviewEvent {
  const _PreviewFlushArrived(this.transcript);

  final List<PreviewItem> transcript;
}

/// El poll falló persistentemente: el fallo se expone y la ventana se apaga
/// (el transcript sigue visible; reabrir rehidrata).
final class _PreviewPollFailed extends PreviewEvent {
  const _PreviewPollFailed(this.failure);

  final TrainerFailure failure;
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
    this.accumulatingUntil,
    this.pendingAttachments = const <PreviewAttachment>[],
  });

  final List<PreviewItem> items;
  final bool sending;

  /// Adjuntos en memoria esperando el próximo send (chips del composer).
  final List<PreviewAttachment> pendingAttachments;

  /// Fallo del último turno (503 sandbox sin cablear, 502 motor...); el
  /// transcript previo sigue visible.
  final TrainerFailure? failure;

  /// Ventana de acumulación viva: el bot junta los mensajes hasta este
  /// instante y los atiende en una corrida. null = sin ventana abierta.
  final DateTime? accumulatingUntil;

  @override
  bool operator ==(Object other) =>
      other is PreviewLoaded &&
      listEquals(other.items, items) &&
      other.sending == sending &&
      other.failure == failure &&
      other.accumulatingUntil == accumulatingUntil &&
      listEquals(other.pendingAttachments, pendingAttachments);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(items),
    sending,
    failure,
    accumulatingUntil,
    Object.hashAll(pendingAttachments),
  );
}

/// Emulador del bot. El turno síncrono se REVELA item por item con la
/// cadencia de un envío real (user inmediato, compás corto entre envíos,
/// `delayMs` del paso simulado clampeado). Con la ventana de acumulación de
/// la plantilla abierta, el turno regresa `pending`: el bloc anuncia la
/// ventana, deja seguir enviando (los mensajes se suman al batch del server)
/// y al cerrarse pollea el transcript hasta que el flush aterriza — entonces
/// lo revela con la misma cadencia.
class PreviewBloc extends Bloc<PreviewEvent, PreviewState> {
  PreviewBloc({
    required PreviewRepository repo,
    required String templateId,
    MediaFilePicker? picker,
    Future<void> Function(Duration)? pace,
  }) : _repo = repo,
       _templateId = templateId,
       _picker = picker,
       _pace = pace ?? ((d) => Future<void>.delayed(d)),
       super(const PreviewLoading()) {
    on<PreviewStarted>(_onStarted);
    on<PreviewMessageSent>(_onMessageSent);
    on<PreviewAttachRequested>(_onAttachRequested);
    on<PreviewAttachmentRemoved>(_onAttachmentRemoved);
    on<PreviewResetRequested>(_onReset);
    on<_PreviewFlushArrived>(_onFlushArrived);
    on<_PreviewPollFailed>(_onPollFailed);
  }

  final PreviewRepository _repo;
  final String _templateId;

  /// Picker de archivos (nil ⇒ el composer oculta el clip — DX/tests).
  final MediaFilePicker? _picker;

  /// Espera entre revelados y entre polls. Inyectable: los tests verifican
  /// cadencia sin dormir relojes reales.
  final Future<void> Function(Duration) _pace;

  /// Compás default entre envíos del bot sin retraso propio: suficiente para
  /// que dos burbujas seguidas se LEAN como dos envíos, sin estorbar.
  static const Duration _stagger = Duration(milliseconds: 450);

  /// Techo del retraso reproducido: un paso con minutos de delay haría
  /// inusable el demo; 6s bastan para SENTIR la cadencia configurada.
  static const Duration _maxStepDelay = Duration(seconds: 6);

  /// Cadencia del poll mientras la ventana/flush siguen vivos en el server.
  static const Duration _pollInterval = Duration(milliseconds: 1500);

  /// Fallos seguidos del poll tolerados antes de rendirse y exponer el error.
  static const int _maxPollFailures = 5;

  /// Un solo poll vivo por bloc; `_pollEpoch` invalida loops huérfanos
  /// (Reset abre época nueva).
  bool _polling = false;
  int _pollEpoch = 0;

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
      final t = await _repo.transcript(templateId: _templateId);
      emit(
        PreviewLoaded(
          items: t.items,
          sending: false,
          accumulatingUntil: t.pending ? t.windowEndsAt ?? _now() : null,
        ),
      );
      // Sesión rehidratada con ventana viva (la app se reabrió mid-batch):
      // retomar el poll para que el flush aterrice sin otro envío.
      if (t.pending) {
        _ensurePolling(t.windowEndsAt ?? _now());
      }
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
    // `sending` bloquea (hay un turno revelándose); la acumulación NO: los
    // mensajes durante la ventana se suman al batch del server.
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
        accumulatingUntil: current.accumulatingUntil,
      ),
    );
    final atts = current.pendingAttachments;
    try {
      final turn = await _repo.sendMessage(
        templateId: _templateId,
        content: event.content,
        attachments: atts,
      );
      if (turn.pending) {
        // Ventana de acumulación: el server grabó el user (reemplaza al
        // optimista) y atenderá el batch al cerrarla. Sin typing — el bot
        // aún no responde; el poll trae el flush. Los adjuntos YA viajaron.
        final until = turn.windowEndsAt ?? _now();
        emit(
          PreviewLoaded(
            items: <PreviewItem>[...current.items, ...turn.items],
            sending: false,
            accumulatingUntil: until,
          ),
        );
        _ensurePolling(until);
        return;
      }
      // Revelado paceado: el turno se pinta item por item (typing encendido
      // entre revelados); el último apaga el typing. El acumulador arranca
      // de `current.items` (pre-optimista): el user del server reemplaza al
      // optimista sin duplicarlo.
      await _reveal(emit, current.items, turn.items);
    } on TrainerFailure catch (f) {
      // El sandbox descarta el turno fallido completo (incluido el item
      // user): revertir el optimista espeja la verdad del server.
      emit(
        PreviewLoaded(
          items: current.items,
          sending: false,
          failure: f,
          accumulatingUntil: current.accumulatingUntil,
        ),
      );
    }
  }

  /// Revela [fresh] item por item sobre [base] con la cadencia configurada.
  Future<void> _reveal(
    Emitter<PreviewState> emit,
    List<PreviewItem> base,
    List<PreviewItem> fresh,
  ) async {
    var acc = base;
    for (var i = 0; i < fresh.length; i++) {
      final wait = _waitFor(fresh[i]);
      if (wait > Duration.zero) {
        await _pace(wait);
      }
      if (isClosed || emit.isDone) return;
      acc = <PreviewItem>[...acc, fresh[i]];
      emit(PreviewLoaded(items: acc, sending: i < fresh.length - 1));
    }
    if (fresh.isEmpty) {
      emit(PreviewLoaded(items: acc, sending: false));
    }
  }

  /// Arranca el poll del flush si no hay uno vivo. Corre FUERA del handler:
  /// bloquear la cola de eventos impediría seguir enviando mensajes durante
  /// la ventana.
  void _ensurePolling(DateTime until) {
    if (_polling) return;
    _polling = true;
    final epoch = _pollEpoch;
    unawaited(_pollLoop(until, epoch));
  }

  Future<void> _pollLoop(DateTime until, int epoch) async {
    try {
      final wait = until.difference(_now());
      if (wait > Duration.zero) {
        await _pace(wait);
      }
      var failures = 0;
      while (!isClosed && epoch == _pollEpoch) {
        // Yield REAL al event loop (timer, no microtask): con un pacer
        // inyectado instantáneo, un loop de puros microtasks monopolizaría
        // la cola — nada más correría y la memoria crecería sin freno.
        await Future<void>.delayed(Duration.zero);
        if (isClosed || epoch != _pollEpoch) return;
        PreviewTranscript t;
        try {
          t = await _repo.transcript(templateId: _templateId);
          failures = 0;
        } on TrainerFailure catch (f) {
          failures++;
          if (failures >= _maxPollFailures) {
            if (!isClosed && epoch == _pollEpoch) {
              add(_PreviewPollFailed(f));
            }
            return;
          }
          await _pace(_pollInterval);
          continue;
        }
        if (!t.pending) {
          if (!isClosed && epoch == _pollEpoch) {
            add(_PreviewFlushArrived(t.items));
          }
          return;
        }
        await _pace(_pollInterval);
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _onFlushArrived(
    _PreviewFlushArrived event,
    Emitter<PreviewState> emit,
  ) async {
    final current = state;
    if (current is! PreviewLoaded) return;
    final transcript = event.transcript;
    // El transcript del server ES la verdad. Lo normal: nuestra lista local
    // (turnos previos + users de la ventana) es prefijo y el flush son los
    // items nuevos al final — se revelan con cadencia. Cualquier otra forma
    // (reset cruzado, sesión expirada) se adopta de golpe, sin inventar.
    if (transcript.length <= current.items.length) {
      emit(PreviewLoaded(items: transcript, sending: false));
      return;
    }
    final fresh = transcript.sublist(current.items.length);
    emit(PreviewLoaded(items: current.items, sending: true));
    await _reveal(emit, current.items, fresh);
  }

  Future<void> _onPollFailed(
    _PreviewPollFailed event,
    Emitter<PreviewState> emit,
  ) async {
    final current = state;
    if (current is! PreviewLoaded) return;
    emit(
      PreviewLoaded(
        items: current.items,
        sending: false,
        failure: event.failure,
      ),
    );
  }

  Future<void> _onAttachRequested(
    PreviewAttachRequested event,
    Emitter<PreviewState> emit,
  ) async {
    final current = state;
    final picker = _picker;
    if (current is! PreviewLoaded || picker == null) return;
    final picked = await picker.pick();
    if (picked == null) return;
    final cur = state;
    if (cur is! PreviewLoaded) return;
    // Misma validación client-side que los chats reales (entrenador/
    // asistente): tipo, peso y cupo se cortan ANTES de aceptar el adjunto,
    // con el mismo copy de fallo. El tipo pesa más que el peso y el peso
    // más que el cupo.
    if (!isSupportedTurnAttachmentName(picked.filename)) {
      emit(
        PreviewLoaded(
          items: cur.items,
          sending: cur.sending,
          failure: const TrainerAttachmentUnsupportedFailure(),
          accumulatingUntil: cur.accumulatingUntil,
          pendingAttachments: cur.pendingAttachments,
        ),
      );
      return;
    }
    if (picked.bytes.length > maxTurnAttachmentBytes) {
      emit(
        PreviewLoaded(
          items: cur.items,
          sending: cur.sending,
          failure: const TrainerAttachmentTooLargeFailure(),
          accumulatingUntil: cur.accumulatingUntil,
          pendingAttachments: cur.pendingAttachments,
        ),
      );
      return;
    }
    if (cur.pendingAttachments.length >= maxTurnAttachments) {
      emit(
        PreviewLoaded(
          items: cur.items,
          sending: cur.sending,
          failure: const TrainerAttachmentLimitFailure(),
          accumulatingUntil: cur.accumulatingUntil,
          pendingAttachments: cur.pendingAttachments,
        ),
      );
      return;
    }
    emit(
      PreviewLoaded(
        items: cur.items,
        sending: cur.sending,
        accumulatingUntil: cur.accumulatingUntil,
        pendingAttachments: <PreviewAttachment>[
          ...cur.pendingAttachments,
          PreviewAttachment(name: picked.filename, bytes: picked.bytes),
        ],
      ),
    );
  }

  void _onAttachmentRemoved(
    PreviewAttachmentRemoved event,
    Emitter<PreviewState> emit,
  ) {
    final current = state;
    if (current is! PreviewLoaded) return;
    emit(
      PreviewLoaded(
        items: current.items,
        sending: current.sending,
        failure: current.failure,
        accumulatingUntil: current.accumulatingUntil,
        pendingAttachments: current.pendingAttachments
            .where((a) => a.name != event.name)
            .toList(growable: false),
      ),
    );
  }

  Future<void> _onReset(
    PreviewResetRequested event,
    Emitter<PreviewState> emit,
  ) async {
    final current = state;
    if (current is! PreviewLoaded) return;
    try {
      await _repo.reset(templateId: _templateId);
      // Época nueva: cualquier poll en vuelo de la sesión vieja muere sin
      // tocar el estado.
      _pollEpoch++;
      emit(const PreviewLoaded(items: <PreviewItem>[], sending: false));
    } on TrainerFailure catch (f) {
      emit(PreviewLoaded(items: current.items, sending: false, failure: f));
    }
  }

  static DateTime _now() => DateTime.now().toUtc();
}
