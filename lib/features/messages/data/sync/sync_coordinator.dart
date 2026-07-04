import 'dart:async';
import 'dart:convert';

import '../../../../core/db/app_db.dart';
import '../../../../core/network/connectivity_monitor.dart';
import '../../domain/failures/messages_failure.dart';
import '../datasources/messages_dao.dart';
import '../datasources/messages_datasource.dart';
import '../datasources/outbox_dao.dart';

/// Espera inyectable: en producción `Future.delayed`; en tests, un control del
/// reloj para no depender del tiempo de pared.
typedef AsyncDelay = Future<void> Function(Duration duration);

enum _Outcome { success, retry, terminal }

/// Drena el outbox: reenvía idempotentemente las escrituras encoladas y
/// reconcilia el resultado contra la DB local (la fuente de verdad de la UI).
///
/// Se dispara al **reconectar** (vía [ConnectivityMonitor]) y al **arrancar**
/// la sesión; además reprograma un re-drain con **backoff** cuando un fallo
/// transitorio ocurre estando en línea (si no, una op `pending` por un 5xx se
/// quedaría "enviando" para siempre sin nada que la vuelva a intentar).
///
/// Garantías:
/// - **Idempotencia**: el `clientToken` persistido se reusa en cada reintento;
///   un reenvío tras un timeout devuelve 200 con el mensaje ya creado (no 409),
///   así que reconciliar no duplica.
/// - **Atomicidad + monotonía**: al confirmar un envío, escribe el `Message`
///   real y borra la fila del outbox en una sola transacción; el upsert pasa
///   por [MessagesDao] (status monótono — no pisa un recibo más nuevo).
/// - **Single-flight**: nunca hay dos drains a la vez; las señales que llegan
///   durante un drain se colapsan en una pasada extra al terminar.
/// - **Fence por generación**: [reset] (cierre de sesión) impide que una
///   reconciliación en vuelo repueble la DB ya purgada de la cuenta anterior.
/// - **Orden FIFO por chat**: si una op de un chat falla reintentable, las
///   posteriores del MISMO chat esperan (no se adelantan).
class SyncCoordinator {
  SyncCoordinator({
    required AppDb db,
    required OutboxDao outbox,
    required MessagesDao messages,
    required MessagesDatasource datasource,
    required ConnectivityMonitor connectivity,
    AsyncDelay delay = _defaultDelay,
    Duration baseBackoff = const Duration(seconds: 2),
    Duration maxBackoff = const Duration(minutes: 1),
  }) : _db = db,
       _outbox = outbox,
       _messages = messages,
       _ds = datasource,
       _delay = delay,
       _baseBackoff = baseBackoff,
       _maxBackoff = maxBackoff {
    _sub = connectivity.onlineChanges.listen((online) {
      if (online) {
        _backoffRound = 0; // enlace fresco: reintenta ya, sin esperar backoff.
        unawaited(drain());
      }
    });
  }

  static Future<void> _defaultDelay(Duration d) => Future<void>.delayed(d);

  final AppDb _db;
  final OutboxDao _outbox;
  final MessagesDao _messages;
  final MessagesDatasource _ds;
  final AsyncDelay _delay;
  final Duration _baseBackoff;
  final Duration _maxBackoff;

  StreamSubscription<bool>? _sub;
  bool _draining = false;
  bool _again = false;
  bool _disposed = false;
  int _epoch = 0;
  int _backoffRound = 0;
  bool _retryScheduled = false;

  /// Rescata operaciones huérfanas (`sending` → `pending`) y drena. Llamar al
  /// arrancar la sesión: un envío interrumpido a media-POST quedó en `sending`.
  Future<void> start() async {
    if (_disposed) return;
    await _outbox.resetOrphanedSending();
    await drain();
  }

  /// Drena el outbox una vez (single-flight). Reentradas concurrentes se
  /// colapsan en una pasada extra al terminar (captura lo encolado durante el
  /// drain). Si quedan operaciones reintentables, reprograma con backoff.
  Future<void> drain() async {
    if (_disposed) return;
    if (_draining) {
      _again = true;
      return;
    }
    _draining = true;
    final epoch = _epoch;
    try {
      var retryablePending = false;
      do {
        _again = false;
        retryablePending = await _drainOnce(epoch);
      } while (_again && !_disposed && epoch == _epoch);
      if (_disposed || epoch != _epoch) return;
      if (retryablePending) {
        _scheduleBackoffRetry(epoch);
      } else {
        _backoffRound = 0;
      }
    } finally {
      _draining = false;
    }
  }

  /// Una pasada FIFO. Devuelve true si quedó alguna op reintentable pendiente.
  Future<bool> _drainOnce(int epoch) async {
    final rows = await _outbox.pending();
    final blockedChats = <String>{};
    var retryablePending = false;
    for (final row in rows) {
      if (_disposed || epoch != _epoch) return retryablePending;
      // El bloqueo FIFO sólo aplica a ENVÍOS (preservan orden entre sí); un
      // mark_read/react ni bloquea ni se bloquea.
      final isSend = row.opType == 'send_message';
      final chatKey = '${row.botId} ${row.chatLid}';
      if (isSend && blockedChats.contains(chatKey)) {
        retryablePending = true;
        continue;
      }
      final outcome = await _dispatch(row, epoch);
      if (outcome == _Outcome.retry) {
        retryablePending = true;
        if (isSend) blockedChats.add(chatKey);
      }
    }
    return retryablePending;
  }

  Future<_Outcome> _dispatch(OutboxRow row, int epoch) async {
    await _outbox.markSending(row.id);
    switch (row.opType) {
      case 'send_message':
        return _handleSend(row, epoch);
      case 'mark_read':
        return _handleMarkRead(row, epoch);
      case 'react':
        return _handleReact(row, epoch);
      default:
        // Tipo no soportado en esta versión: terminal, para no ciclar.
        await _outbox.markFailedTerminal(row.id, errorKind: 'unsupported_op');
        return _Outcome.terminal;
    }
  }

  Future<_Outcome> _handleMarkRead(OutboxRow row, int epoch) async {
    final String? upTo;
    try {
      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      upTo = payload['upToMessageId'] as String?;
    } catch (_) {
      await _outbox.markFailedTerminal(row.id, errorKind: 'corrupt_payload');
      return _Outcome.terminal;
    }
    return _runSimple(
      row,
      epoch,
      () => _ds.markRead(row.botId, row.chatLid, upToMessageId: upTo),
    );
  }

  Future<_Outcome> _handleReact(OutboxRow row, int epoch) async {
    final String messageId;
    final String emoji;
    try {
      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      messageId = payload['messageId'] as String;
      emoji = (payload['emoji'] as String?) ?? '';
    } catch (_) {
      await _outbox.markFailedTerminal(row.id, errorKind: 'corrupt_payload');
      return _Outcome.terminal;
    }
    // Re-coalesce en el dispatch: si ya hay una reacción más nueva para el mismo
    // mensaje, ésta quedó obsoleta (una nueva intención la superó mientras estaba
    // en vuelo / huérfana). Descártala sin POSTear, para que no aterrice DESPUÉS
    // y pise la última intención del usuario.
    if (await _outbox.hasNewerReact(
      row.botId,
      row.chatLid,
      messageId,
      afterId: row.id,
    )) {
      await _outbox.deleteById(row.id);
      return _Outcome.success;
    }
    return _runSimple(
      row,
      epoch,
      () =>
          _ds.react(row.botId, row.chatLid, messageId: messageId, emoji: emoji),
    );
  }

  /// Ejecuta una op SIN reconciliación (mark_read/react): la llama y borra la
  /// fila al éxito; misma taxonomía retry/terminal que el envío. (No escribe en
  /// `messages`, así que el fence sólo evita un borrado innecesario tras logout.)
  Future<_Outcome> _runSimple(
    OutboxRow row,
    int epoch,
    Future<void> Function() op,
  ) async {
    try {
      await op();
      if (_disposed || epoch != _epoch) return _Outcome.success;
      await _outbox.deleteById(row.id);
      return _Outcome.success;
    } on MessagesFailure catch (e) {
      if (_disposed || epoch != _epoch) return _Outcome.terminal;
      final kind = _errorKind(e);
      if (_isRetryable(e)) {
        await _outbox.markRetry(row.id, errorKind: kind);
        return _Outcome.retry;
      }
      await _outbox.markFailedTerminal(row.id, errorKind: kind);
      return _Outcome.terminal;
    } catch (_) {
      if (_disposed || epoch != _epoch) return _Outcome.terminal;
      await _outbox.markRetry(row.id, errorKind: 'local');
      return _Outcome.retry;
    }
  }

  Future<_Outcome> _handleSend(OutboxRow row, int epoch) async {
    final token = row.clientToken;
    if (token == null) {
      await _outbox.markFailedTerminal(row.id, errorKind: 'missing_token');
      return _Outcome.terminal;
    }
    final String type;
    final String content;
    final String? mediaRef;
    final List<int>? waveform;
    final String? quotedId;
    final String? fileName;
    try {
      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      type = payload['type'] as String;
      content = (payload['content'] as String?) ?? '';
      mediaRef = payload['mediaRef'] as String?;
      waveform = (payload['waveform'] as List<dynamic>?)?.cast<int>();
      quotedId = payload['quotedId'] as String?;
      fileName = payload['fileName'] as String?;
    } catch (_) {
      // Payload corrupto (error determinista): terminal — reintentar no ayuda.
      await _outbox.markFailedTerminal(row.id, errorKind: 'corrupt_payload');
      return _Outcome.terminal;
    }
    try {
      final msg = await _ds.send(
        row.botId,
        row.chatLid,
        clientToken: token,
        type: type,
        content: content,
        mediaRef: mediaRef,
        waveform: waveform,
        quotedId: quotedId,
        fileName: fileName,
      );
      if (_disposed || epoch != _epoch) return _Outcome.success;
      await _db.transaction(() async {
        // Fence DENTRO de la transacción (atómico con la escritura, no un
        // TOCTOU): si se cerró sesión mientras el POST estaba en vuelo, no
        // repueblo la DB ya purgada de la cuenta anterior.
        if (_disposed || epoch != _epoch) return;
        await _messages.upsertMessages(row.botId, [msg]);
        await _outbox.deleteById(row.id);
      });
      return _Outcome.success;
    } on MessagesFailure catch (e) {
      if (_disposed || epoch != _epoch) return _Outcome.terminal;
      final kind = _errorKind(e);
      if (_isRetryable(e)) {
        await _outbox.markRetry(row.id, errorKind: kind);
        return _Outcome.retry;
      }
      await _outbox.markFailedTerminal(row.id, errorKind: kind);
      return _Outcome.terminal;
    } catch (_) {
      // Error LOCAL inesperado tras un POST ya aceptado (p. ej. la transacción
      // de reconciliación falló por un error de DB transitorio): revierte a
      // pending para re-reconciliar; el replay idempotente evita duplicar (sin
      // esto la fila quedaría atascada en `sending` hasta reiniciar la app).
      if (_disposed || epoch != _epoch) return _Outcome.terminal;
      await _outbox.markRetry(row.id, errorKind: 'local');
      return _Outcome.retry;
    }
  }

  void _scheduleBackoffRetry(int epoch) {
    if (_retryScheduled) return;
    _retryScheduled = true;
    final wait = _backoffFor(_backoffRound);
    _backoffRound++;
    unawaited(() async {
      await _delay(wait);
      // Si la sesión cambió (reset) o se cerró, este timer es de una generación
      // vieja: no toca el flag (lo gestiona reset) ni drena la sesión nueva.
      if (_disposed || epoch != _epoch) return;
      _retryScheduled = false;
      await drain();
    }());
  }

  Duration _backoffFor(int round) {
    final shift = round.clamp(0, 16);
    final ms = _baseBackoff.inMilliseconds << shift;
    final capped = ms < _maxBackoff.inMilliseconds
        ? ms
        : _maxBackoff.inMilliseconds;
    return Duration(milliseconds: capped);
  }

  /// Cierre de sesión: incrementa la generación para fencear cualquier
  /// reconciliación en vuelo (no debe escribir tras la purga). El outbox lo
  /// vacía `clearAllData`; la próxima sesión drena en limpio.
  void reset() {
    _epoch++;
    _backoffRound = 0;
    _again = false;
    // Libera el flag para que la sesión siguiente pueda programar su propio
    // backoff (un timer de la sesión vieja queda neutralizado por el epoch).
    _retryScheduled = false;
  }

  Future<void> close() async {
    _disposed = true;
    await _sub?.cancel();
  }

  static bool _isRetryable(MessagesFailure f) => switch (f) {
    MessagesNetworkFailure() ||
    MessagesTimeoutFailure() ||
    MessagesServerFailure() ||
    MessagesNotConnectedFailure() ||
    MessagesWireFailure() => true,
    _ => false,
  };

  static String _errorKind(MessagesFailure f) => switch (f) {
    MessagesNetworkFailure() => 'network',
    MessagesTimeoutFailure() => 'timeout',
    MessagesServerFailure() => 'server',
    MessagesNotConnectedFailure() => 'not_connected',
    MessagesWireFailure() => 'wire',
    MessagesConflictFailure() => 'conflict',
    MessagesValidationFailure() => 'validation',
    MessagesForbiddenFailure() => 'forbidden',
    MessagesNotFoundFailure() => 'not_found',
    MessagesBotPausedFailure() => 'bot_paused',
    UnknownMessagesFailure() => 'unknown',
  };
}
