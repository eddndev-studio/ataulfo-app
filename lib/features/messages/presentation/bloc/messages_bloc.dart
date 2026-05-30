import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/message.dart';
import '../../domain/entities/thread_live_event.dart';
import '../../domain/failures/messages_failure.dart';
import '../../domain/repositories/messages_repository.dart';

/// Bloc del hilo de mensajes (S09 RF#5 + realtime S15). Se construye con
/// `botId` + `chatLid` (los aporta la ruta `/bots/:id/sessions/:chatLid`). Abre
/// en la cola (mensajes recientes) y carga tramos más viejos al pedir `Older`,
/// prependiéndolos — el modelo de scroll de un chat.
///
/// `prevCursor` dentro de `MessagesLoaded` es el cursor hacia atrás: `null` ⇒
/// inicio del hilo (no hay más viejos). `isLoadingOlder` deja que la UI muestre
/// el spinner de "cargando más" sin ocultar el hilo ya pintado.
///
/// **Realtime:** tras la carga inicial se suscribe al stream SSE del bot
/// (`repo.live`) y agrega en vivo los mensajes nuevos del chat abierto —tanto
/// entrantes del contacto como las auto-respuestas del bot (flujo/IA), que el
/// backend publica en `message.outbound`—. Es un overlay best-effort sobre la
/// verdad HTTP: dedupa por `externalId` y, si el stream cae, el hilo ya pintado
/// se conserva (el pull-to-refresh recupera).
class MessagesBloc extends Bloc<MessagesEvent, MessagesState> {
  MessagesBloc({
    required MessagesRepository repo,
    required String botId,
    required String chatLid,
  }) : _repo = repo,
       _botId = botId,
       _chatLid = chatLid,
       super(const MessagesInitial()) {
    on<MessagesLoadRequested>(_onLoad);
    on<MessagesOlderRequested>(_onOlder);
    on<MessagesLiveReceived>(_onLive);
    on<MessagesStatusReceived>(_onStatus);
    on<MessagesReconnected>(_onReconnected);
  }

  final MessagesRepository _repo;
  final String _botId;
  final String _chatLid;

  StreamSubscription<ThreadLiveEvent>? _liveSub;

  /// Evita refetchs solapados cuando llegan varias reconexiones seguidas
  /// (flapping): si ya hay uno en vuelo, las demás se ignoran (el dedup las
  /// haría inocuas, pero ahorramos las llamadas HTTP).
  bool _refetching = false;

  Future<void> _onLoad(
    MessagesLoadRequested event,
    Emitter<MessagesState> emit,
  ) async {
    emit(const MessagesLoading());
    try {
      final page = await _repo.thread(_botId, _chatLid);
      emit(
        MessagesLoaded(
          items: page.messages,
          prevCursor: page.prevCursor,
          isLoadingOlder: false,
        ),
      );
      // El realtime arranca DESPUÉS de pintar la cola: así `_onLive` sólo
      // corre sobre un `MessagesLoaded` y no compite con la carga inicial.
      _startLive();
    } on MessagesFailure catch (f) {
      emit(MessagesFailed(f));
    }
  }

  /// Abre (o reabre) la suscripción al stream en vivo del bot. Reentrante: una
  /// recarga cancela la suscripción previa antes de abrir otra, para no
  /// duplicar entregas. Cada mensaje del stream se reinyecta como evento del
  /// bloc, de modo que el append vive en un solo punto (`_onLive`).
  void _startLive() {
    _liveSub?.cancel();
    _liveSub = _repo.live(_botId).listen(
      (e) {
        switch (e) {
          case LiveMessage(:final message):
            add(MessagesLiveReceived(message));
          case LiveStatus(:final externalId, :final status):
            add(MessagesStatusReceived(externalId: externalId, status: status));
          case LiveReconnected():
            add(const MessagesReconnected());
        }
      },
      // Realtime caído NO derriba el hilo: el state HTTP sigue válido.
      onError: (Object _) {},
    );
  }

  void _onLive(MessagesLiveReceived event, Emitter<MessagesState> emit) {
    final current = state;
    if (current is! MessagesLoaded) {
      return;
    }
    final m = event.message;
    // Sólo el chat abierto: el stream es por-bot y puede traer otras
    // conversaciones del mismo bot.
    if (m.chatLid != _chatLid) {
      return;
    }
    // Dedup por externalId: el mensaje pudo entrar ya por la cola HTTP, o
    // llegar repetido (p. ej. un envío manual en message.inbound + su echo).
    if (current.items.any((x) => x.externalId == m.externalId)) {
      return;
    }
    // Los mensajes en vivo son los más nuevos: se anexan al final (ASC).
    emit(
      MessagesLoaded(
        items: <Message>[...current.items, m],
        prevCursor: current.prevCursor,
        isLoadingOlder: current.isLoadingOlder,
      ),
    );
  }

  /// Aplica un receipt en vivo (`message.status`): localiza el OUTBOUND por
  /// `externalId` (único global ⇒ no hace falta `chatLid`) y avanza su estado de
  /// entrega. La monotonía la decide `MessageStatus.transition` (sólo avanza;
  /// retroceso/igual/stale = no-op). Un receipt de un mensaje que no está en el
  /// hilo abierto se ignora.
  void _onStatus(MessagesStatusReceived event, Emitter<MessagesState> emit) {
    final current = state;
    if (current is! MessagesLoaded) {
      return;
    }
    final i = current.items.indexWhere((m) => m.externalId == event.externalId);
    if (i < 0) {
      return;
    }
    final advanced = MessageStatus.transition(
      current.items[i].status,
      event.status,
    );
    if (advanced == null) {
      return; // no-op: el estado no avanza
    }
    final items = List<Message>.of(current.items);
    items[i] = items[i].withStatus(advanced);
    emit(
      MessagesLoaded(
        items: items,
        prevCursor: current.prevCursor,
        isLoadingOlder: current.isLoadingOlder,
      ),
    );
  }

  /// Tras reconectar el stream en vivo, reconcilia contra la verdad HTTP: el SSE
  /// no reproduce lo emitido durante el corte, así que refetcha la cola y funde
  /// lo perdido. Dos clases de pérdida se recuperan aquí:
  ///
  ///   - **Mensajes del hueco:** los que no estaban se agregan; reordenados por
  ///     `(timestampMs, externalId)` para que caigan en su sitio cronológico.
  ///   - **Avances de estado del hueco:** un OUTBOUND ya pintado pudo avanzar
  ///     (p. ej. SENT→READ) sin que sus `message.status` llegaran en vivo. READ
  ///     es terminal —no llega otro receipt—, así que sin reconciliar el tick
  ///     quedaría stale. Se avanza desde la verdad HTTP con la misma monotonía
  ///     (`transition`), conservando el resto del mensaje ya pintado.
  ///
  /// Re-emite sólo si hubo un cambio real (mensaje nuevo o avance de estado): un
  /// avance no cambia el conteo de items, de ahí el flag en vez de comparar
  /// longitudes. Best-effort: si el refetch falla, el hilo en vivo se conserva.
  Future<void> _onReconnected(
    MessagesReconnected event,
    Emitter<MessagesState> emit,
  ) async {
    if (state is! MessagesLoaded || _refetching) {
      return;
    }
    _refetching = true;
    try {
      final page = await _repo.thread(_botId, _chatLid);
      final current = state;
      if (current is! MessagesLoaded) {
        return;
      }
      final byId = <String, Message>{
        for (final m in current.items) m.externalId: m,
      };
      var changed = false;
      for (final m in page.messages) {
        final existing = byId[m.externalId];
        if (existing == null) {
          byId[m.externalId] = m; // mensaje del hueco
          changed = true;
        } else if (m.status != null) {
          final advanced = MessageStatus.transition(existing.status, m.status!);
          if (advanced != null) {
            byId[m.externalId] = existing.withStatus(advanced);
            changed = true;
          }
        }
      }
      if (!changed) {
        return; // nada nuevo ni avance de estado: no re-emitir
      }
      final merged = byId.values.toList()
        ..sort((a, b) {
          final byTime = a.timestampMs.compareTo(b.timestampMs);
          return byTime != 0 ? byTime : a.externalId.compareTo(b.externalId);
        });
      emit(
        MessagesLoaded(
          items: merged,
          prevCursor: current.prevCursor,
          isLoadingOlder: current.isLoadingOlder,
        ),
      );
    } on MessagesFailure {
      // Refetch best-effort: una reconexión sin red no debe derribar el hilo.
    } finally {
      _refetching = false;
    }
  }

  @override
  Future<void> close() {
    _liveSub?.cancel();
    return super.close();
  }

  Future<void> _onOlder(
    MessagesOlderRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final current = state;
    // Sólo paginamos hacia arriba desde un hilo ya cargado, con más tramo
    // disponible (prevCursor != null) y sin otra carga en vuelo.
    if (current is! MessagesLoaded ||
        current.prevCursor == null ||
        current.isLoadingOlder) {
      return;
    }
    emit(
      MessagesLoaded(
        items: current.items,
        prevCursor: current.prevCursor,
        isLoadingOlder: true,
      ),
    );
    try {
      final older = await _repo.thread(
        _botId,
        _chatLid,
        cursor: current.prevCursor,
      );
      // El tramo viejo es estrictamente anterior (keyset `<`): se prepende sin
      // solape ni dedup. Ambas listas vienen en ASC.
      emit(
        MessagesLoaded(
          items: <Message>[...older.messages, ...current.items],
          prevCursor: older.prevCursor,
          isLoadingOlder: false,
        ),
      );
    } on MessagesFailure {
      // Fallar al cargar más viejos NO derriba el hilo ya pintado: se apaga el
      // spinner y se conserva el estado (el usuario puede reintentar el scroll).
      emit(
        MessagesLoaded(
          items: current.items,
          prevCursor: current.prevCursor,
          isLoadingOlder: false,
        ),
      );
    }
  }
}

// Events --------------------------------------------------------------------

sealed class MessagesEvent {
  const MessagesEvent();
}

/// Carga inicial: la cola (mensajes más recientes) del hilo.
class MessagesLoadRequested extends MessagesEvent {
  const MessagesLoadRequested();
  @override
  bool operator ==(Object other) => other is MessagesLoadRequested;
  @override
  int get hashCode => (MessagesLoadRequested).hashCode;
}

/// Cargar el tramo inmediatamente más viejo (scroll hacia arriba).
class MessagesOlderRequested extends MessagesEvent {
  const MessagesOlderRequested();
  @override
  bool operator ==(Object other) => other is MessagesOlderRequested;
  @override
  int get hashCode => (MessagesOlderRequested).hashCode;
}

/// Llegó un mensaje en vivo del stream SSE (S15). Lo produce la suscripción a
/// `repo.live`; el handler lo agrega al hilo si es del chat abierto y no estaba
/// ya presente (dedup por externalId).
class MessagesLiveReceived extends MessagesEvent {
  const MessagesLiveReceived(this.message);

  final Message message;

  @override
  bool operator ==(Object other) =>
      other is MessagesLiveReceived && other.message == message;
  @override
  int get hashCode => message.hashCode;
}

/// Llegó un receipt en vivo (`message.status`): el OUTBOUND `externalId` avanzó
/// a `status`. Lo produce la suscripción a `repo.live`; el handler localiza el
/// mensaje en el hilo abierto y repinta su estado de entrega (monótono).
class MessagesStatusReceived extends MessagesEvent {
  const MessagesStatusReceived({
    required this.externalId,
    required this.status,
  });

  final String externalId;
  final MessageStatus status;

  @override
  bool operator ==(Object other) =>
      other is MessagesStatusReceived &&
      other.externalId == externalId &&
      other.status == status;
  @override
  int get hashCode => Object.hash(externalId, status);
}

/// El stream en vivo se reconectó tras un corte (S15). Dispara una reconciliación
/// contra la verdad HTTP para recuperar los mensajes que el SSE no reprodujo.
class MessagesReconnected extends MessagesEvent {
  const MessagesReconnected();
  @override
  bool operator ==(Object other) => other is MessagesReconnected;
  @override
  int get hashCode => (MessagesReconnected).hashCode;
}

// States --------------------------------------------------------------------

sealed class MessagesState {
  const MessagesState();
}

class MessagesInitial extends MessagesState {
  const MessagesInitial();
  @override
  bool operator ==(Object other) => other is MessagesInitial;
  @override
  int get hashCode => (MessagesInitial).hashCode;
}

class MessagesLoading extends MessagesState {
  const MessagesLoading();
  @override
  bool operator ==(Object other) => other is MessagesLoading;
  @override
  int get hashCode => (MessagesLoading).hashCode;
}

class MessagesLoaded extends MessagesState {
  const MessagesLoaded({
    required this.items,
    required this.prevCursor,
    required this.isLoadingOlder,
  });

  /// Mensajes acumulados en orden ascendente (más viejo→más nuevo).
  final List<Message> items;

  /// Cursor hacia atrás; `null` ⇒ inicio del hilo (no hay más viejos).
  final String? prevCursor;

  /// Hay un tramo más viejo cargándose (spinner arriba, hilo visible).
  final bool isLoadingOlder;

  bool get hasMore => prevCursor != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MessagesLoaded) return false;
    if (other.prevCursor != prevCursor) return false;
    if (other.isLoadingOlder != isLoadingOlder) return false;
    if (other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(items), prevCursor, isLoadingOlder);
}

class MessagesFailed extends MessagesState {
  const MessagesFailed(this.failure);

  final MessagesFailure failure;

  @override
  bool operator ==(Object other) =>
      other is MessagesFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
