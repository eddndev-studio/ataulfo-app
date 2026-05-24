import 'package:dio/dio.dart';

import '../../domain/entities/bot.dart';
import '../../domain/failures/bots_failure.dart';
import '../dto/bot_dto.dart';
import '../mappers/bots_mapper.dart';

/// Puerto de datos para los endpoints de Bot (S04).
///
/// Las implementaciones lanzan `BotsFailure` tipadas; nunca DioException
/// cruda. El repositorio y el bloc consumen failures de dominio.
abstract interface class BotsDatasource {
  /// `GET /bots` org-scoped. El AuthInterceptor inyecta el Bearer; aquí no
  /// se gestiona. WORKER ve solo asignados; SUPERVISOR+ ve todos
  /// (decisión RBAC del backend, no del cliente).
  Future<List<Bot>> list();
}

class DioBotsDatasource implements BotsDatasource {
  DioBotsDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<Bot>> list() async {
    try {
      final res = await _dio.get<List<dynamic>>('/bots');
      final body = res.data;
      if (body == null) {
        throw const UnknownBotsFailure();
      }
      return body
          .cast<Map<String, dynamic>>()
          .map(BotResp.fromJson)
          .map(BotsMapper.botRespToEntity)
          .toList(growable: false);
    } on BotsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownBotsFailure();
    } on TypeError {
      // `cast<Map<String,dynamic>>` puede romper si el wire mete un tipo
      // inesperado; el contrato dice array de objetos.
      throw const UnknownBotsFailure();
    }
  }

  /// Traduce DioException a la jerarquía sellada de BotsFailure. Duplica el
  /// patrón de AuthFailure._mapDioException con los códigos de S04 (403 vs
  /// 401-de-login). Regla de tres: refactor a un helper compartido en el
  /// próximo feature que lo necesite.
  BotsFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const BotsTimeoutFailure();
      case DioExceptionType.connectionError:
        return const BotsNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const BotsForbiddenFailure();
        if (status >= 500 && status < 600) return const BotsServerFailure();
        return const UnknownBotsFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownBotsFailure();
    }
  }
}
