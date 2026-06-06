import 'package:dio/dio.dart';

import '../../domain/entities/message.dart';
import '../../domain/entities/message_page.dart';
import '../../domain/failures/messages_failure.dart';
import '../dto/message_dto.dart';
import '../mappers/messages_mapper.dart';

/// Puerto de datos del hilo de mensajes (S09 RF#5).
///
/// Las implementaciones lanzan `MessagesFailure` tipadas; nunca DioException
/// cruda. El repositorio y el bloc consumen failures de dominio.
abstract interface class MessagesDatasource {
  /// `GET /sessions/:botId/:chatLid/messages` org-scoped. Sin `cursor` ⇒ la
  /// cola (más recientes); con `cursor` ⇒ el tramo más viejo. Devuelve la
  /// página (puede tener `messages` vacía).
  Future<MessagePage> thread(
    String botId,
    String chatLid, {
    String? cursor,
    int? limit,
  });

  /// `POST /sessions/:botId/:chatLid/messages/send`. Envía un mensaje del
  /// operador (texto o imagen). `clientToken` es la idempotency-key del cliente
  /// (mismo token + mismo contenido ⇒ 200 con el Message ya persistido; mismo
  /// token + contenido distinto ⇒ `MessagesConflictFailure`). `type` es `text`
  /// o `image`; para `image` `mediaRef` es obligatorio (ref BARE previamente
  /// subido) y `content` es el caption opcional. Devuelve el Message persistido
  /// (su `externalId` es el wamid asignado por el servidor).
  Future<Message> send(
    String botId,
    String chatLid, {
    required String clientToken,
    required String type,
    String content,
    String? mediaRef,
  });

  /// `POST /sessions/:botId/:chatLid/mark-read`. Marca como leídos los INBOUND
  /// del chat (todos si `upToMessageId` es null; hasta ese id inclusive si se
  /// indica). Devuelve `markedCount` (best-effort por sender). Envía palomitas
  /// de leído reales al contacto.
  Future<int> markRead(String botId, String chatLid, {String? upToMessageId});

  /// `POST /sessions/:botId/:chatLid/react`. Reacciona al mensaje `messageId`
  /// con `emoji`; `emoji` vacío quita la reacción previa del bot. 204 sin cuerpo.
  Future<void> react(
    String botId,
    String chatLid, {
    required String messageId,
    required String emoji,
  });
}

class DioMessagesDatasource implements MessagesDatasource {
  DioMessagesDatasource(this._dio);

  final Dio _dio;

  @override
  Future<MessagePage> thread(
    String botId,
    String chatLid, {
    String? cursor,
    int? limit,
  }) async {
    try {
      // El chatLid se percent-encodea: los grupos llevan `@` (`...@g.us`),
      // que rompería el segmento del path. El backend lo decodifica vía
      // PathValue.
      final res = await _dio.get<Map<String, dynamic>>(
        '/sessions/$botId/${Uri.encodeComponent(chatLid)}/messages',
        queryParameters: <String, dynamic>{'cursor': ?cursor, 'limit': ?limit},
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownMessagesFailure();
      }
      return MessagesMapper.respToPage(MessageThreadResp.fromJson(body));
    } on MessagesFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      // Body malformado: contrato roto.
      throw const UnknownMessagesFailure();
    } on TypeError {
      // `cast<Map<String,dynamic>>` rompe si el wire mete un tipo inesperado.
      throw const UnknownMessagesFailure();
    } on ArgumentError {
      // kind/direction desconocido (drift de enum): contrato roto.
      throw const UnknownMessagesFailure();
    }
  }

  @override
  Future<Message> send(
    String botId,
    String chatLid, {
    required String clientToken,
    required String type,
    String content = '',
    String? mediaRef,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/sessions/$botId/${Uri.encodeComponent(chatLid)}/messages/send',
        data: <String, dynamic>{
          'clientToken': clientToken,
          'type': type,
          'content': content,
          'mediaRef': ?mediaRef,
        },
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownMessagesFailure();
      }
      return MessagesMapper.respToMessage(MessageResp.fromJson(body));
    } on MessagesFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapWrite(e);
    } on FormatException {
      throw const UnknownMessagesFailure();
    } on TypeError {
      throw const UnknownMessagesFailure();
    } on ArgumentError {
      throw const UnknownMessagesFailure();
    }
  }

  @override
  Future<int> markRead(
    String botId,
    String chatLid, {
    String? upToMessageId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/sessions/$botId/${Uri.encodeComponent(chatLid)}/mark-read',
        data: <String, dynamic>{'upToMessageId': ?upToMessageId},
      );
      final count = res.data?['markedCount'];
      if (count is! int) {
        throw const UnknownMessagesFailure();
      }
      return count;
    } on MessagesFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapWrite(e);
    } on TypeError {
      throw const UnknownMessagesFailure();
    }
  }

  @override
  Future<void> react(
    String botId,
    String chatLid, {
    required String messageId,
    required String emoji,
  }) async {
    try {
      await _dio.post<void>(
        '/sessions/$botId/${Uri.encodeComponent(chatLid)}/react',
        data: <String, dynamic>{'messageId': messageId, 'emoji': emoji},
      );
    } on DioException catch (e) {
      throw _mapWrite(e);
    }
  }

  /// Traduce DioException a la jerarquía sellada. Mismo patrón que el resto de
  /// datasources: 404 = bot ajeno/inexistente (el endpoint autoriza por bot;
  /// una sesión inexistente da 200 vacío, no 404); 409 colapsa a Unknown.
  MessagesFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const MessagesTimeoutFailure();
      case DioExceptionType.connectionError:
        return const MessagesNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const MessagesForbiddenFailure();
        if (status == 404) return const MessagesNotFoundFailure();
        if (status >= 500 && status < 600) {
          return const MessagesServerFailure();
        }
        return const UnknownMessagesFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownMessagesFailure();
    }
  }

  /// Traduce DioException del path de ESCRITURA (send/react/mark-read). A
  /// diferencia de `_mapDioException` (GET del hilo), discrimina 409 (conflicto
  /// de idempotencia), 422 (validación), 423 (bot pausado), 502 (wire) y 503
  /// (bot no corriendo) en failures propias. 404 = fresh-chat (send) / target
  /// inexistente (react) / bot ajeno; 403 = RBAC.
  MessagesFailure _mapWrite(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const MessagesTimeoutFailure();
      case DioExceptionType.connectionError:
        return const MessagesNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        return switch (status) {
          403 => const MessagesForbiddenFailure(),
          404 => const MessagesNotFoundFailure(),
          409 => const MessagesConflictFailure(),
          422 => const MessagesValidationFailure(),
          423 => const MessagesBotPausedFailure(),
          502 => const MessagesWireFailure(),
          503 => const MessagesNotConnectedFailure(),
          _ when status >= 500 && status < 600 => const MessagesServerFailure(),
          _ => const UnknownMessagesFailure(),
        };
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownMessagesFailure();
    }
  }
}
