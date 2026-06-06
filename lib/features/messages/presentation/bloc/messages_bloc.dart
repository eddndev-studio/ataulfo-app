// Nota de tamaño (>400 LOC): este archivo concentra la máquina de estados
// cohesiva del hilo —carga + paginación + realtime (mensajes y receipts) +
// envío optimista con reconciliación contra el eco SSE—. Partirla dispersaría
// lógica fuertemente acoplada: todas las transiciones comparten `MessagesLoaded`
// y su invariante de dedup por `externalId`, así que se conserva junta.
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

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
    String Function()? clientTokenFactory,
  }) : _repo = repo,
       _botId = botId,
       _chatLid = chatLid,
       _newToken = clientTokenFactory ?? _uuidV4,
       super(const MessagesInitial()) {
    on<MessagesLoadRequested>(_onLoad);
    on<MessagesOlderRequested>(_onOlder);
    on<MessagesLiveReceived>(_onLive);
    on<MessagesStatusReceived>(_onStatus);
    on<MessagesReconnected>(_onReconnected);
    on<MessagesSendRequested>(_onSend);
    on<MessagesSendRetryRequested>(_onRetry);
    on<MessagesSendDiscarded>(_onDiscard);
  }

  static String _uuidV4() => const Uuid().v4();

  final MessagesRepository _repo;
  final String _botId;
  final String _chatLid;

  /// Genera la idempotency-key (`clientToken`) de cada envío. Inyectable para
  /// tests deterministas; por defecto un UUID v4.
  final String Function() _newToken;

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
      // Abrir el hilo lo marca como leído (decisión de producto: al abrir, no
      // al responder). Best-effort y silencioso.
      _markReadOnOpen();
    } on MessagesFailure catch (f) {
      emit(MessagesFailed(f));
    }
  }

  /// Marca el chat como leído al abrirlo. Envía palomitas de leído REALES al
  /// contacto, así que es un efecto de un solo disparo por apertura (no en la
  /// paginación ni en el refetch de reconexión). Best-effort y silencioso: no
  /// emite estado —el badge de no-leídos vive en la lista, que se refresca al
  /// volver— y un fallo no toca el hilo. `Future.sync` envuelve la llamada para
  /// que un throw (incluso síncrono) caiga en `catchError` y no escape.
  void _markReadOnOpen() {
    unawaited(
      Future<int>.sync(
        () => _repo.markRead(_botId, _chatLid),
      ).catchError((Object _) => 0),
    );
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
    emit(current.copyWith(items: <Message>[...current.items, m]));
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
    emit(current.copyWith(items: items));
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
      emit(current.copyWith(items: merged));
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
    emit(current.copyWith(isLoadingOlder: true));
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
          pending: current.pending,
        ),
      );
    } on MessagesFailure {
      // Fallar al cargar más viejos NO derriba el hilo ya pintado: se apaga el
      // spinner y se conserva el estado (el usuario puede reintentar el scroll).
      emit(current.copyWith(isLoadingOlder: false));
    }
  }

  /// Envía un mensaje del operador con UI optimista. Pinta de inmediato una
  /// burbuja pendiente (clave: el `clientToken` recién generado — ni el 200 ni
  /// el eco SSE lo traen) y dispara el POST; `_dispatchSend` reconcilia.
  Future<void> _onSend(
    MessagesSendRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final current = state;
    if (current is! MessagesLoaded) {
      return;
    }
    final pending = PendingSend(
      clientToken: _newToken(),
      type: event.type,
      content: event.content,
      mediaRef: event.mediaRef,
    );
    emit(current.copyWith(pending: <PendingSend>[...current.pending, pending]));
    await _dispatchSend(pending, emit);
  }

  /// Reintenta un envío fallido REUSANDO su `clientToken` (idempotencia: si el
  /// mensaje llegó a salir, el backend devuelve 200 con el Message ya
  /// persistido en vez de duplicar). Re-marca la burbuja como enviando y
  /// redispara.
  Future<void> _onRetry(
    MessagesSendRetryRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final current = state;
    if (current is! MessagesLoaded) {
      return;
    }
    final i = current.pending.indexWhere(
      (p) => p.clientToken == event.clientToken,
    );
    if (i < 0) {
      return;
    }
    final retrying = current.pending[i].asSending();
    final pending = List<PendingSend>.of(current.pending)..[i] = retrying;
    emit(current.copyWith(pending: pending));
    await _dispatchSend(retrying, emit);
  }

  /// Descarta una burbuja pendiente (típicamente fallida) sin enviar nada.
  void _onDiscard(MessagesSendDiscarded event, Emitter<MessagesState> emit) {
    final current = state;
    if (current is! MessagesLoaded) {
      return;
    }
    emit(
      current.copyWith(
        pending: current.pending
            .where((p) => p.clientToken != event.clientToken)
            .toList(growable: false),
      ),
    );
  }

  /// POST del envío. Tras el await relee el estado FRESCO: entre el envío y su
  /// resolución pudo entrar un evento en vivo que mutó el hilo (incl. el eco SSE
  /// del propio envío). Reconcilia la burbuja con el Message del 200 —o lo deja
  /// si el eco ya lo agregó (dedup por externalId)— y, si falla, marca la
  /// burbuja como fallida sin tocar el hilo.
  Future<void> _dispatchSend(
    PendingSend pending,
    Emitter<MessagesState> emit,
  ) async {
    try {
      final msg = await _repo.send(
        _botId,
        _chatLid,
        clientToken: pending.clientToken,
        type: pending.type,
        content: pending.content,
        mediaRef: pending.mediaRef,
      );
      if (isClosed) {
        return;
      }
      final s = state;
      if (s is! MessagesLoaded) {
        return;
      }
      final cleared = s.pending
          .where((p) => p.clientToken != pending.clientToken)
          .toList(growable: false);
      final already = s.items.any((x) => x.externalId == msg.externalId);
      emit(
        s.copyWith(
          items: already ? s.items : <Message>[...s.items, msg],
          pending: cleared,
        ),
      );
    } on MessagesFailure catch (f) {
      if (isClosed) {
        return;
      }
      final s = state;
      if (s is! MessagesLoaded) {
        return;
      }
      emit(
        s.copyWith(
          pending: <PendingSend>[
            for (final p in s.pending)
              if (p.clientToken == pending.clientToken) p.asFailed(f) else p,
          ],
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

/// El operador pide enviar un mensaje (S09). `type` es `text`/`image`; para
/// imagen `mediaRef` es el ref BARE ya subido y `content` el caption opcional.
class MessagesSendRequested extends MessagesEvent {
  const MessagesSendRequested({
    required this.type,
    required this.content,
    this.mediaRef,
  });

  final String type;
  final String content;
  final String? mediaRef;

  @override
  bool operator ==(Object other) =>
      other is MessagesSendRequested &&
      other.type == type &&
      other.content == content &&
      other.mediaRef == mediaRef;
  @override
  int get hashCode => Object.hash(type, content, mediaRef);
}

/// Reintenta un envío fallido reusando su `clientToken` (idempotente).
class MessagesSendRetryRequested extends MessagesEvent {
  const MessagesSendRetryRequested(this.clientToken);

  final String clientToken;

  @override
  bool operator ==(Object other) =>
      other is MessagesSendRetryRequested && other.clientToken == clientToken;
  @override
  int get hashCode => clientToken.hashCode;
}

/// Descarta una burbuja pendiente/fallida sin enviarla.
class MessagesSendDiscarded extends MessagesEvent {
  const MessagesSendDiscarded(this.clientToken);

  final String clientToken;

  @override
  bool operator ==(Object other) =>
      other is MessagesSendDiscarded && other.clientToken == clientToken;
  @override
  int get hashCode => clientToken.hashCode;
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
    this.pending = const <PendingSend>[],
  });

  /// Mensajes acumulados en orden ascendente (más viejo→más nuevo).
  final List<Message> items;

  /// Cursor hacia atrás; `null` ⇒ inicio del hilo (no hay más viejos).
  final String? prevCursor;

  /// Hay un tramo más viejo cargándose (spinner arriba, hilo visible).
  final bool isLoadingOlder;

  /// Envíos optimistas en vuelo o fallidos, en orden de emisión. Se pintan como
  /// burbujas salientes al fondo del hilo hasta que el 200 los reconcilia con
  /// su Message (por wamid) o el operador los reintenta/descarta.
  final List<PendingSend> pending;

  bool get hasMore => prevCursor != null;

  /// Copia conservando `prevCursor` (que sólo cambia en la paginación, donde el
  /// estado se construye explícito): así un cambio de `items`/`pending` no puede
  /// borrar el cursor por la ambigüedad null de un copyWith genérico.
  MessagesLoaded copyWith({
    List<Message>? items,
    bool? isLoadingOlder,
    List<PendingSend>? pending,
  }) => MessagesLoaded(
    items: items ?? this.items,
    prevCursor: prevCursor,
    isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
    pending: pending ?? this.pending,
  );

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
    if (other.pending.length != pending.length) return false;
    for (var i = 0; i < pending.length; i++) {
      if (other.pending[i] != pending[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(items),
    prevCursor,
    isLoadingOlder,
    Object.hashAll(pending),
  );
}

/// Un envío optimista del operador: en vuelo (`failure == null`) o fallido. Se
/// identifica por su `clientToken` (idempotency-key) porque ni el 200 ni el eco
/// SSE lo traen — sólo así se reconcilia la burbuja con el Message real.
class PendingSend {
  const PendingSend({
    required this.clientToken,
    required this.type,
    required this.content,
    this.mediaRef,
    this.failure,
  });

  final String clientToken;
  final String type;
  final String content;
  final String? mediaRef;

  /// `null` mientras está en vuelo; no-null si el envío falló (la burbuja ofrece
  /// reintentar/descartar).
  final MessagesFailure? failure;

  bool get isFailed => failure != null;

  PendingSend asSending() => PendingSend(
    clientToken: clientToken,
    type: type,
    content: content,
    mediaRef: mediaRef,
  );

  PendingSend asFailed(MessagesFailure f) => PendingSend(
    clientToken: clientToken,
    type: type,
    content: content,
    mediaRef: mediaRef,
    failure: f,
  );

  @override
  bool operator ==(Object other) =>
      other is PendingSend &&
      other.clientToken == clientToken &&
      other.type == type &&
      other.content == content &&
      other.mediaRef == mediaRef &&
      other.failure == failure;

  @override
  int get hashCode =>
      Object.hash(clientToken, type, content, mediaRef, failure);
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
