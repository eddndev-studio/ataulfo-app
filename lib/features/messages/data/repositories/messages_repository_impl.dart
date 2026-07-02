import 'dart:async';

import '../../domain/entities/message.dart';
import '../../domain/entities/outbox_entry.dart';
import '../../domain/entities/thread_live_event.dart';
import '../../domain/failures/messages_failure.dart';
import '../../domain/repositories/messages_repository.dart';
import '../datasources/messages_dao.dart';
import '../datasources/messages_datasource.dart';
import '../datasources/messages_events_datasource.dart';
import '../datasources/outbox_dao.dart';
import '../mappers/message_row_mapper.dart';
import '../mappers/outbox_entry_mapper.dart';

/// Orquesta verdad local vs. remota (RFC-0001): la UI observa la DB
/// (`watchThread`) y la red la alimenta write-through. El HTTP es autoritativo;
/// el SSE es best-effort y el reconcile (refreshThread) recupera el tramo del
/// corte. El ENVÍO va al outbox durable (`watchPending` + `requestSync` dispara
/// el drain del coordinador, que reconcilia el mensaje real). markRead/react/
/// live siguen delegando a los datasources.
class MessagesRepositoryImpl implements MessagesRepository {
  MessagesRepositoryImpl({
    required MessagesDatasource datasource,
    required MessagesEventsDatasource events,
    required MessagesDao dao,
    required OutboxDao outbox,
    required void Function() requestSync,
    Future<void> Function(String botId, String chatLid)? markConversationRead,
  }) : _ds = datasource,
       _events = events,
       _dao = dao,
       _outbox = outbox,
       _requestSync = requestSync,
       _markConversationRead = markConversationRead;

  final MessagesDatasource _ds;
  final MessagesEventsDatasource _events;
  final MessagesDao _dao;
  final OutboxDao _outbox;

  /// Dispara un drain del coordinador (fire-and-forget) tras encolar/revivir una
  /// escritura, para que el envío salga ya si hay red.
  final void Function() _requestSync;

  /// Baja los no-leídos de la fila de la bandeja (write-through optimista al
  /// marcar leído). Inyectado desde la composición para no acoplar la feature
  /// de mensajes al DAO de conversaciones; nulo ⇒ sin proyección a la bandeja.
  final Future<void> Function(String botId, String chatLid)?
  _markConversationRead;

  /// Firmas `mediaUrl` vivas por `(botId, externalId)` (clave I-M1; el wamid no
  /// es único entre bots), conservadas en memoria durante la sesión: la DB NO
  /// persiste la firma efímera, así que la red (HTTP/SSE) la recuerda aquí y
  /// `watchThread` la re-inyecta sobre las filas. Sólo mensajes con media;
  /// offline/en frío queda vacío y el visor cae a la caché en disco.
  final Map<String, String> _liveMediaUrls = <String, String>{};

  static String _mediaKey(String botId, String externalId) =>
      '$botId|$externalId';

  @override
  Stream<List<Message>> watchThread(String botId, String chatLid) => _dao
      .watchThread(botId, chatLid)
      .map(
        (rows) => rows
            .map(
              (r) => MessageRowMapper.rowToEntity(
                r,
                mediaUrl: _liveMediaUrls[_mediaKey(botId, r.externalId)],
              ),
            )
            .toList(growable: false),
      )
      .handleError(
        (Object _) => throw const UnknownMessagesFailure(),
        test: (Object? e) => e is! MessagesFailure,
      );

  /// Recuerda las firmas vivas de los mensajes con media para re-inyectarlas en
  /// [watchThread] (la DB las descarta). Sólo guarda las no nulas.
  void _rememberMediaUrls(String botId, Iterable<Message> messages) {
    for (final m in messages) {
      final url = m.mediaUrl;
      if (m.mediaRef != null && url != null) {
        _liveMediaUrls[_mediaKey(botId, m.externalId)] = url;
      }
    }
  }

  @override
  Future<String?> threadCursor(String botId, String chatLid) async {
    try {
      final c = await _dao.threadCursor(botId, chatLid);
      return c.reachedStart ? null : c.cursor;
    } catch (_) {
      return null; // siembra best-effort de hasMore
    }
  }

  @override
  Future<String?> refreshThread(
    String botId,
    String chatLid, {
    bool resetCursor = true,
  }) => _pullInto(botId, chatLid, cursor: null, setCursor: resetCursor);

  @override
  Future<String?> loadOlder(String botId, String chatLid) async {
    final cur = await _dao.threadCursor(botId, chatLid);
    if (cur.reachedStart || cur.cursor == null) return null;
    return _pullInto(botId, chatLid, cursor: cur.cursor, setCursor: true);
  }

  /// Trae una página (cola o tramo viejo) y la escribe write-through. El fetch
  /// HTTP ocurre ANTES de escribir: un fallo de red deja la caché intacta. Si
  /// `setCursor`, persiste el cursor de backfill. Un error no tipado (drift) se
  /// traduce a MessagesFailure.
  Future<String?> _pullInto(
    String botId,
    String chatLid, {
    required String? cursor,
    required bool setCursor,
  }) async {
    try {
      final page = await _ds.thread(botId, chatLid, cursor: cursor);
      _rememberMediaUrls(botId, page.messages);
      await _dao.upsertMessages(botId, page.messages);
      if (setCursor) {
        await _dao.setThreadCursor(
          botId,
          chatLid,
          oldestCursor: page.prevCursor,
          reachedStart: page.prevCursor == null,
        );
      }
      return page.prevCursor;
    } on MessagesFailure {
      rethrow;
    } catch (_) {
      throw const UnknownMessagesFailure();
    }
  }

  @override
  Future<void> applyLiveMessage(String botId, Message message) async {
    try {
      _rememberMediaUrls(botId, [message]);
      await _dao.upsertMessages(botId, [message]);
    } catch (_) {
      // Best-effort: el reconcile por HTTP recupera lo que no se pudo persistir.
    }
  }

  @override
  Future<void> applyStatus(
    String botId,
    String externalId,
    MessageStatus status,
  ) async {
    try {
      await _dao.applyStatus(botId, externalId, status);
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Stream<List<OutboxEntry>> watchPending(String botId, String chatLid) =>
      _outbox
          .watchForChat(botId, chatLid)
          .map(
            (rows) => rows
                .map(OutboxEntryMapper.fromRow)
                .whereType<OutboxEntry>()
                .toList(growable: false),
          );

  @override
  Future<void> send(
    String botId,
    String chatLid, {
    required String clientToken,
    required String type,
    String content = '',
    String? mediaRef,
    List<int>? waveform,
    String? quotedId,
  }) async {
    await _outbox.enqueueSend(
      botId: botId,
      chatLid: chatLid,
      clientToken: clientToken,
      type: type,
      content: content,
      mediaRef: mediaRef,
      waveform: waveform,
      quotedId: quotedId,
    );
    _requestSync();
  }

  @override
  Future<void> retrySend(
    String botId,
    String chatLid,
    String clientToken,
  ) async {
    await _outbox.retryByToken(botId, chatLid, clientToken);
    _requestSync();
  }

  @override
  Future<void> discardSend(String botId, String chatLid, String clientToken) =>
      _outbox.deleteByToken(botId, chatLid, clientToken);

  @override
  Future<void> markRead(
    String botId,
    String chatLid, {
    String? upToMessageId,
  }) async {
    await _outbox.enqueueMarkRead(
      botId: botId,
      chatLid: chatLid,
      upToMessageId: upToMessageId,
    );
    // Write-through optimista a la bandeja: baja el badge de no-leídos de la
    // fila local ya (el backend lo reconcilia en el próximo refresh). Sin
    // esto, abrir un chat no limpiaba el badge de la bandeja hasta un pull.
    final markConversationRead = _markConversationRead;
    if (markConversationRead != null) {
      unawaited(markConversationRead(botId, chatLid).catchError((Object _) {}));
    }
    _requestSync();
  }

  @override
  Future<void> react(
    String botId,
    String chatLid, {
    required String messageId,
    required String emoji,
  }) async {
    await _outbox.enqueueReact(
      botId: botId,
      chatLid: chatLid,
      messageId: messageId,
      emoji: emoji,
    );
    _requestSync();
  }

  @override
  Stream<ThreadLiveEvent> live(String botId) => _events.threadEvents(botId);
}
