import 'package:dio/dio.dart';

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
}
