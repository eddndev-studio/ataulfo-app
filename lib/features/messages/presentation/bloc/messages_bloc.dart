// Nota de tamaño (>400 LOC): este archivo concentra la máquina de estados
// cohesiva del hilo —carga + paginación + realtime (mensajes y receipts) +
// envío vía outbox durable—. Partirla dispersaría lógica fuertemente acoplada:
// todas las transiciones comparten `MessagesLoaded` y su modelo de vista
// combinada (items del watch de la DB de mensajes + las burbujas derivadas del
// watch del outbox + cursor/loadingOlder), así que se conserva junta.
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/message.dart';
import '../../domain/entities/outbox_entry.dart';
import '../../domain/entities/thread_live_event.dart';
import '../../domain/failures/messages_failure.dart';
import '../../domain/repositories/messages_repository.dart';

/// Bloc del hilo de mensajes (S09 RF#5 + realtime S15). Se construye con
/// `botId` + `chatLid` (los aporta la ruta `/bots/:id/sessions/:chatLid`).
///
/// **DB como fuente de verdad:** `items` salen del watch de la DB local
/// (`repo.watchThread`, orden ascendente). La red la alimenta write-through: la
/// carga inicial y el reconcile traen la cola HTTP, la paginación trae tramos
/// viejos por cursor, y el realtime SSE (mensajes + receipts) se escribe en la
/// DB; el watch repinta. Las burbujas pendientes (`pending`) se DERIVAN de un
/// segundo watch, el del OUTBOX durable (`repo.watchPending`): el envío encola
/// ahí y sobrevive a un cierre/offline; el cursor de paginación y el flag de
/// "cargando más" los lleva el bloc por encima de ambos watches.
///
/// `prevCursor` en `MessagesLoaded`: `null` ⇒ inicio del hilo (no hay más
/// viejos). `isLoadingOlder` muestra el spinner sin ocultar el hilo. Offline,
/// el watch sigue sirviendo la última caché; un refresh fallido con caché no
/// degrada a error.
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
    on<MessagesReactRequested>(_onReact);
    on<_MessagesDbEmitted>(_onDbEmitted);
    on<_MessagesPendingEmitted>(_onPendingEmitted);
    on<_MessagesWatchFailed>(_onWatchFailed);
  }

  static String _uuidV4() => const Uuid().v4();

  final MessagesRepository _repo;
  final String _botId;
  final String _chatLid;

  /// Sesión del hilo (bot + chat) para que la UI arme rutas dependientes del
  /// chat (p.ej. el drill-through a la corrida de IA de un mensaje).
  String get botId => _botId;
  String get chatLid => _chatLid;

  /// Genera la idempotency-key (`clientToken`) de cada envío. Inyectable para
  /// tests deterministas; por defecto un UUID v4.
  final String Function() _newToken;

  /// Side-channel de fallos de reacción. Reaccionar no emite estados (la
  /// reacción se materializa por el eco SSE), así que un POST fallido sería
  /// invisible; este stream permite a la UI anunciarlo sin tocar el hilo.
  final StreamController<void> _reactFailures =
      StreamController<void>.broadcast();

  Stream<void> get reactFailures => _reactFailures.stream;

  StreamSubscription<ThreadLiveEvent>? _liveSub;
  StreamSubscription<List<Message>>? _itemsSub;
  StreamSubscription<List<OutboxEntry>>? _pendingSub;

  /// Evita refetchs solapados cuando llegan varias reconexiones seguidas.
  bool _refetching = false;

  /// Ya hubo una primera emisión de `MessagesLoaded` (carga resuelta): hasta
  /// entonces no se pinta una bandeja vacía para no parpadear antes del refresh.
  bool _started = false;

  // Vista combinada de `MessagesLoaded`: `items` del watch de la DB de mensajes;
  // `_pendingEntries` del watch del OUTBOX durable (los envíos encolados,
  // sobreviven a reinicios). `pending` se DERIVA de ambos en `_derivePending`.
  List<Message> _items = const <Message>[];
  String? _prevCursor;
  bool _loadingOlder = false;
  List<OutboxEntry> _pendingEntries = const <OutboxEntry>[];

  void _emitLoaded(Emitter<MessagesState> emit) {
    emit(
      MessagesLoaded(
        items: _items,
        prevCursor: _prevCursor,
        isLoadingOlder: _loadingOlder,
        pending: _derivePending(),
      ),
    );
  }

  /// Proyecta las entradas del outbox a burbujas, deduplicando el eco SSE: si el
  /// eco escribió el mensaje real ANTES de que el coordinador borre la fila del
  /// outbox (carrera eco-vs-200), suprime la burbuja para no mostrarla doble.
  /// Emparejamiento 1:1 (un mensaje real consume una burbuja) por
  /// OUTBOUND + type + content + timestamp ≥ createdAt; el sesgo es seguro
  /// (ante duda, MUESTRA la burbuja: un duplicado de un frame es ruido, una
  /// burbuja que falta se lee como "mi mensaje se perdió").
  List<PendingSend> _derivePending() {
    if (_pendingEntries.isEmpty) return const <PendingSend>[];
    final consumed = <int>{};
    final out = <PendingSend>[];
    for (final e in _pendingEntries) {
      var matched = false;
      for (var i = 0; i < _items.length; i++) {
        if (consumed.contains(i)) continue;
        final m = _items[i];
        if (m.direction == MessageDirection.outbound &&
            m.type == e.type &&
            m.content == e.content &&
            m.timestampMs >= e.createdAtMs) {
          consumed.add(i);
          matched = true;
          break;
        }
      }
      if (!matched) out.add(_toPending(e));
    }
    return out;
  }

  PendingSend _toPending(OutboxEntry e) => PendingSend(
    clientToken: e.clientToken,
    type: e.type,
    content: e.content,
    mediaRef: e.mediaRef,
    quotedId: e.quotedId,
    // Sólo un fallo TERMINAL pinta error+reintento; un reintentable sigue
    // "enviando" (el coordinador lo reintenta solo).
    failure: e.isFailed ? _failureFromKind(e.errorKind) : null,
  );

  /// Reconstruye un `MessagesFailure` desde el `errorKind` persistido para que la
  /// UI muestre el texto de error correcto. Los kinds internos (corrupt_payload,
  /// etc.) caen a genérico.
  static MessagesFailure _failureFromKind(String? kind) => switch (kind) {
    'network' => const MessagesNetworkFailure(),
    'timeout' => const MessagesTimeoutFailure(),
    'server' => const MessagesServerFailure(),
    'not_connected' => const MessagesNotConnectedFailure(),
    'wire' => const MessagesWireFailure(),
    'conflict' => const MessagesConflictFailure(),
    'validation' => const MessagesValidationFailure(),
    'forbidden' => const MessagesForbiddenFailure(),
    'not_found' => const MessagesNotFoundFailure(),
    'bot_paused' => const MessagesBotPausedFailure(),
    _ => const UnknownMessagesFailure(),
  };

  Future<void> _onLoad(
    MessagesLoadRequested event,
    Emitter<MessagesState> emit,
  ) async {
    if (!_started) emit(const MessagesLoading());
    // Siembra `hasMore` (también offline) desde el cursor persistido.
    _prevCursor = await _repo.threadCursor(_botId, _chatLid);
    if (isClosed) return;
    // Una sola suscripción al watch; los reintentos sólo re-disparan el refresh.
    _itemsSub ??= _repo
        .watchThread(_botId, _chatLid)
        .listen(
          (items) => add(_MessagesDbEmitted(items)),
          onError: (Object e) {
            if (e is MessagesFailure) add(_MessagesWatchFailed(e));
          },
        );
    // Watch del outbox durable: las burbujas pendientes/fallidas (sobreviven a
    // reinicios). Un error aquí NO derriba el hilo.
    _pendingSub ??= _repo
        .watchPending(_botId, _chatLid)
        .listen(
          (entries) => add(_MessagesPendingEmitted(entries)),
          onError: (Object _) {},
        );
    try {
      _prevCursor = await _repo.refreshThread(_botId, _chatLid);
      if (isClosed) return;
      _started = true;
      _emitLoaded(emit);
      // El realtime arranca DESPUÉS de la primera carga; escribe write-through.
      _startLive();
      // Abrir el hilo lo marca como leído (al abrir, no al responder).
      _markReadOnOpen();
    } on MessagesFailure catch (f) {
      if (isClosed) return;
      if (_items.isEmpty && _pendingEntries.isEmpty && !_started) {
        emit(
          MessagesFailed(f),
        ); // sin caché ni pendientes: el fallo sube a la UI
      } else {
        // Offline con caché (o con envíos encolados): el watch ya pintó; el
        // realtime reintenta solo.
        _started = true;
        _emitLoaded(emit);
        _startLive();
        _markReadOnOpen();
      }
    }
  }

  void _onDbEmitted(_MessagesDbEmitted event, Emitter<MessagesState> emit) {
    _items = event.items;
    // No se pinta una bandeja vacía antes del primer refresh (evita parpadeo).
    // En cuanto hay algo que mostrar (caché o un envío encolado), `_started` se
    // marca: así el envío y la paginación quedan habilitados mientras el refresh
    // sigue en vuelo (offline-first), igualando lo que la UI ya presenta.
    if (_started || _items.isNotEmpty || _pendingEntries.isNotEmpty) {
      _emitLoaded(emit);
      _started = true;
    }
  }

  void _onPendingEmitted(
    _MessagesPendingEmitted event,
    Emitter<MessagesState> emit,
  ) {
    _pendingEntries = event.entries;
    // Una entrada durable basta para arrancar el hilo: si el watch de mensajes
    // emitió un error (Failed) antes del primer dato, esta emisión recupera el
    // estado y no esconde la burbuja durable tras la pantalla de error. Espeja
    // la condición de _onDbEmitted. (live/markRead los arranca SOLO _onLoad.)
    if (_started || _items.isNotEmpty || _pendingEntries.isNotEmpty) {
      _emitLoaded(emit);
      _started = true;
    }
  }

  void _onWatchFailed(_MessagesWatchFailed event, Emitter<MessagesState> emit) {
    // Sólo sube a error si no hay NADA que mostrar: ni caché ni envíos
    // encolados (un error del watch de mensajes no dice nada del outbox).
    if (_items.isEmpty && _pendingEntries.isEmpty && !_started) {
      emit(MessagesFailed(event.failure));
    }
  }

  /// Marca el chat como leído al abrirlo (un disparo por apertura). Encola un
  /// mark-read durable que se reintenta al reconectar; el coalescing del outbox
  /// evita acumular reaperturas. Best-effort sobre el encolado local.
  void _markReadOnOpen() {
    unawaited(_repo.markRead(_botId, _chatLid).catchError((Object _) {}));
  }

  /// Abre (o reabre) la suscripción SSE del bot. Reentrante: cancela la previa.
  /// Cada evento se reinyecta como evento del bloc; el handler lo escribe en la
  /// DB (write-through) y el watch repinta.
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
      // Realtime caído NO derriba el hilo: la caché del watch sigue válida.
      onError: (Object _) {},
    );
  }

  Future<void> _onLive(
    MessagesLiveReceived event,
    Emitter<MessagesState> emit,
  ) async {
    final m = event.message;
    // Sólo el chat abierto: el stream es por-bot.
    if (m.chatLid != _chatLid) return;
    // Write-through: el dedup por `externalId` y la monotonía de status los
    // garantiza el upsert del DAO; el watch repinta.
    await _repo.applyLiveMessage(_botId, m);
  }

  Future<void> _onStatus(
    MessagesStatusReceived event,
    Emitter<MessagesState> emit,
  ) async {
    // El receipt avanza (monótono) el status del mensaje en la DB; el watch
    // repinta. `externalId` es único global ⇒ no hace falta `chatLid`.
    await _repo.applyStatus(_botId, event.externalId, event.status);
  }

  /// Tras reconectar, reconcilia contra la verdad HTTP (el SSE no reproduce el
  /// tramo del corte). Escribe la cola fresca write-through SIN reubicar el
  /// cursor de paginación del usuario; el watch funde y el DAO aplica la
  /// monotonía de status. Best-effort.
  Future<void> _onReconnected(
    MessagesReconnected event,
    Emitter<MessagesState> emit,
  ) async {
    if (_refetching) return;
    _refetching = true;
    try {
      await _repo.refreshThread(_botId, _chatLid, resetCursor: false);
    } on MessagesFailure {
      // Reconexión sin red: el hilo en vivo se conserva.
    } finally {
      _refetching = false;
    }
  }

  Future<void> _onOlder(
    MessagesOlderRequested event,
    Emitter<MessagesState> emit,
  ) async {
    if (!_started || _prevCursor == null || _loadingOlder) return;
    _loadingOlder = true;
    _emitLoaded(emit);
    try {
      // Escribe el tramo viejo write-through y avanza el cursor; el watch lo
      // prepende (orden ASC de la DB).
      _prevCursor = await _repo.loadOlder(_botId, _chatLid);
    } on MessagesFailure {
      // Fallar al cargar más viejos NO derriba el hilo: sólo se apaga el spinner.
    } finally {
      if (!isClosed) {
        _loadingOlder = false;
        _emitLoaded(emit);
      }
    }
  }

  /// Envío del operador. Encola la escritura en el outbox durable (con un
  /// `clientToken` recién generado) y dispara el drain; la burbuja pendiente
  /// aparece por el watch del outbox y el coordinador reconcilia el mensaje real
  /// contra la DB. Sobrevive a un cierre/offline: no vive en memoria.
  Future<void> _onSend(
    MessagesSendRequested event,
    Emitter<MessagesState> emit,
  ) async {
    if (!_started) return;
    try {
      await _repo.send(
        _botId,
        _chatLid,
        clientToken: _newToken(),
        type: event.type,
        content: event.content,
        mediaRef: event.mediaRef,
        waveform: event.waveform,
        quotedId: event.quotedId,
      );
    } on Object {
      // El encolado es local; un fallo aquí es excepcional (DB). Best-effort.
    }
  }

  /// Reintenta un envío fallido REUSANDO su `clientToken` (idempotente: si llegó
  /// a salir, el backend devuelve el Message ya persistido en vez de duplicar).
  /// Revive la fila del outbox; el watch repinta la burbuja como "enviando".
  Future<void> _onRetry(
    MessagesSendRetryRequested event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      await _repo.retrySend(_botId, _chatLid, event.clientToken);
    } on Object {
      // Best-effort: actualización local + disparo de drain.
    }
  }

  /// Descarta un envío encolado (típicamente fallido) sin enviarlo. Si el
  /// servidor ya lo había aceptado, el mensaje real se recupera en el próximo
  /// refresh; descartar la fila del outbox NO es pérdida de datos.
  Future<void> _onDiscard(
    MessagesSendDiscarded event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      await _repo.discardSend(_botId, _chatLid, event.clientToken);
    } on Object {
      // Best-effort.
    }
  }

  /// Reacciona a un mensaje. Encola una reacción durable que se reintenta al
  /// reconectar (la reacción se materializa por el eco SSE). El [reactFailures]
  /// sólo señaliza un fallo del encolado local (excepcional); los fallos de red
  /// ya no se anuncian aquí porque se reintentan solos.
  Future<void> _onReact(
    MessagesReactRequested event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      await _repo.react(
        _botId,
        _chatLid,
        messageId: event.messageId,
        emoji: event.emoji,
      );
    } on Object {
      _reactFailures.add(null);
    }
  }

  @override
  Future<void> close() {
    _liveSub?.cancel();
    _itemsSub?.cancel();
    _pendingSub?.cancel();
    _reactFailures.close();
    return super.close();
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
/// `repo.live`; el handler lo escribe write-through si es del chat abierto (el
/// dedup por externalId lo hace el upsert del DAO).
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
/// a `status`. Lo produce la suscripción a `repo.live`; el handler lo aplica
/// (monótono) en la DB.
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
/// contra la verdad HTTP para recuperar lo que el SSE no reprodujo.
class MessagesReconnected extends MessagesEvent {
  const MessagesReconnected();
  @override
  bool operator ==(Object other) => other is MessagesReconnected;
  @override
  int get hashCode => (MessagesReconnected).hashCode;
}

/// El operador pide enviar un mensaje (S09). `type` es `text`/`image`/`ptt`;
/// para media `mediaRef` es el ref BARE ya subido y `content` el caption
/// opcional. `waveform` (sólo `ptt`) son las muestras de amplitud 0-100 que
/// el cliente computó al grabar; el backend las pone en el waveform nativo.
class MessagesSendRequested extends MessagesEvent {
  const MessagesSendRequested({
    required this.type,
    required this.content,
    this.mediaRef,
    this.waveform,
    this.quotedId,
  });

  final String type;
  final String content;
  final String? mediaRef;
  final List<int>? waveform;

  /// `externalId` del mensaje citado si este envío es una respuesta; `null` en
  /// un envío normal.
  final String? quotedId;

  @override
  bool operator ==(Object other) =>
      other is MessagesSendRequested &&
      other.type == type &&
      other.content == content &&
      other.mediaRef == mediaRef &&
      other.quotedId == quotedId &&
      _sameWaveform(other.waveform, waveform);
  @override
  int get hashCode => Object.hash(
    type,
    content,
    mediaRef,
    quotedId,
    Object.hashAll(waveform ?? const <int>[]),
  );
}

bool _sameWaveform(List<int>? a, List<int>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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

/// El operador reacciona al mensaje `messageId` con `emoji` (S09); `emoji` vacío
/// quita la reacción previa.
class MessagesReactRequested extends MessagesEvent {
  const MessagesReactRequested({required this.messageId, required this.emoji});

  final String messageId;
  final String emoji;

  @override
  bool operator ==(Object other) =>
      other is MessagesReactRequested &&
      other.messageId == messageId &&
      other.emoji == emoji;
  @override
  int get hashCode => Object.hash(messageId, emoji);
}

/// Interno: nueva emisión del watch de la DB con el hilo completo (ASC).
class _MessagesDbEmitted extends MessagesEvent {
  const _MessagesDbEmitted(this.items);
  final List<Message> items;
}

/// Interno: nueva emisión del watch del outbox (envíos encolados del chat).
class _MessagesPendingEmitted extends MessagesEvent {
  const _MessagesPendingEmitted(this.entries);
  final List<OutboxEntry> entries;
}

/// Interno: el watch de la DB emitió un error (ya tipado por el repo).
class _MessagesWatchFailed extends MessagesEvent {
  const _MessagesWatchFailed(this.failure);
  final MessagesFailure failure;
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
  /// burbujas salientes al fondo del hilo hasta que el mensaje real aparece (por
  /// wamid) o el operador los reintenta/descarta.
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
    this.quotedId,
    this.failure,
  });

  final String clientToken;
  final String type;
  final String content;
  final String? mediaRef;

  /// `externalId` del mensaje citado si el envío optimista es una respuesta.
  final String? quotedId;

  /// `null` mientras está en vuelo; no-null si el envío falló (la burbuja ofrece
  /// reintentar/descartar).
  final MessagesFailure? failure;

  bool get isFailed => failure != null;

  @override
  bool operator ==(Object other) =>
      other is PendingSend &&
      other.clientToken == clientToken &&
      other.type == type &&
      other.content == content &&
      other.mediaRef == mediaRef &&
      other.quotedId == quotedId &&
      other.failure == failure;

  @override
  int get hashCode =>
      Object.hash(clientToken, type, content, mediaRef, quotedId, failure);
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
