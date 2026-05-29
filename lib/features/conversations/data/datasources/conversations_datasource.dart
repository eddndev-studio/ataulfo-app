import 'package:dio/dio.dart';

import '../../domain/entities/conversation.dart';
import '../../domain/failures/conversations_failure.dart';
import '../dto/conversation_dto.dart';
import '../mappers/conversations_mapper.dart';

/// Puerto de datos del listado de conversaciones de un bot (S07 RF#7).
///
/// Las implementaciones lanzan `ConversationsFailure` tipadas; nunca
/// DioException cruda. El repositorio y el bloc consumen failures de dominio.
abstract interface class ConversationsDatasource {
  /// `GET /sessions/:botId` org-scoped. El AuthInterceptor inyecta el Bearer.
  /// El backend autoriza por propiedad del bot (404 si ajeno/inexistente) y
  /// omite las sesiones provisionales. Devuelve la bandeja (puede ser vacía).
  Future<List<Conversation>> listForBot(String botId);
}

class DioConversationsDatasource implements ConversationsDatasource {
  DioConversationsDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<Conversation>> listForBot(String botId) async {
    try {
      final res = await _dio.get<List<dynamic>>('/sessions/$botId');
      final body = res.data;
      if (body == null) {
        throw const UnknownConversationsFailure();
      }
      return body
          .cast<Map<String, dynamic>>()
          .map(ConversationResp.fromJson)
          .map(ConversationsMapper.respToEntity)
          .toList(growable: false);
    } on ConversationsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      // Body malformado o muted_until no parseable: contrato roto.
      throw const UnknownConversationsFailure();
    } on TypeError {
      // `cast<Map<String,dynamic>>` rompe si el wire mete un tipo inesperado.
      throw const UnknownConversationsFailure();
    }
  }

  /// Traduce DioException a la jerarquía sellada. Mismo patrón que
  /// `DioBotsDatasource`: 404 = bot ajeno/inexistente (el endpoint autoriza
  /// por bot); 409 (sin org activa) no se distingue — colapsa a Unknown.
  ConversationsFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ConversationsTimeoutFailure();
      case DioExceptionType.connectionError:
        return const ConversationsNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const ConversationsForbiddenFailure();
        if (status == 404) return const ConversationsNotFoundFailure();
        if (status >= 500 && status < 600) {
          return const ConversationsServerFailure();
        }
        return const UnknownConversationsFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownConversationsFailure();
    }
  }
}
