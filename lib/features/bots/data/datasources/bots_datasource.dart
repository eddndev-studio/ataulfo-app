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

  /// `GET /bots/:id` org-scoped. 404 si el ID no existe en la org activa;
  /// 403 si el rol no alcanza (típicamente WORKER sin asignación al bot).
  Future<Bot> byId(String id);

  /// `POST /bots` body `{template_id, name, channel, identifier?}`. 422
  /// colapsa las cuatro variantes del dominio del backend (`ErrInvalidBot`,
  /// `ErrInvalidChannel`, `ErrTemplateNotFound`, `ErrVariableNotInDefs`)
  /// en un único `BotsInvalidCreateFailure`. El `identifier` (label libre
  /// opcional v1) viaja sólo si no está vacío (omitempty, espejo de createReq).
  Future<Bot> create({
    required String templateId,
    required String name,
    required BotChannel channel,
    String? identifier,
  });

  /// `PUT /bots/:id` con CAS optimista. Cuerpo tristate: los campos null se
  /// omiten ("no tocar"); `version` siempre viaja. Devuelve el Bot ya
  /// actualizado (con `version+1`). Mapeo de errores POR-ENDPOINT: un 409 es
  /// `BotsConflictFailure` (conflicto de versión); 422 →
  /// `BotsInvalidCreateFailure`; 404 → `BotsNotFoundFailure`. `channel` e
  /// `identifier` NO viajan (inmutables / create-only).
  Future<Bot> update({
    required String id,
    required int version,
    String? name,
    bool? paused,
    bool? aiDisabled,
    Map<String, String>? variableValues,
  });

  /// `POST /bots/:id/clone` body `{name}` ⇒ 201. Devuelve el Bot clonado con
  /// un id NUEVO (canal y plantilla heredados, version reiniciada). 422 si el
  /// nombre es inválido; 404 si el bot origen no existe. No usa CAS de versión.
  Future<Bot> clone({required String id, required String name});

  /// `DELETE /bots/:id` ⇒ 204. Borra el bot (deja huérfanas sessions/messages/
  /// executions sin FK). 404 si ya no existe. No usa CAS de versión.
  Future<void> delete(String id);
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

  @override
  Future<Bot> byId(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/bots/$id');
      final body = res.data;
      if (body == null) {
        throw const UnknownBotsFailure();
      }
      return BotsMapper.botRespToEntity(BotResp.fromJson(body));
    } on BotsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownBotsFailure();
    } on TypeError {
      throw const UnknownBotsFailure();
    }
  }

  @override
  Future<Bot> create({
    required String templateId,
    required String name,
    required BotChannel channel,
    String? identifier,
  }) async {
    try {
      final trimmedId = identifier?.trim() ?? '';
      final res = await _dio.post<Map<String, dynamic>>(
        '/bots',
        data: <String, dynamic>{
          'template_id': templateId,
          'name': name,
          'channel': channel.toWire(),
          // omitempty: el identifier sólo viaja si el operador lo escribió.
          if (trimmedId.isNotEmpty) 'identifier': trimmedId,
        },
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownBotsFailure();
      }
      return BotsMapper.botRespToEntity(BotResp.fromJson(body));
    } on BotsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownBotsFailure();
    } on TypeError {
      throw const UnknownBotsFailure();
    }
  }

  @override
  Future<Bot> update({
    required String id,
    required int version,
    String? name,
    bool? paused,
    bool? aiDisabled,
    Map<String, String>? variableValues,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/bots/$id',
        data: BotUpdateReq(
          version: version,
          name: name,
          paused: paused,
          aiDisabled: aiDisabled,
          variableValues: variableValues,
        ).toJson(),
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownBotsFailure();
      }
      return BotsMapper.botRespToEntity(BotResp.fromJson(body));
    } on BotsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e, versionConflict: true);
    } on FormatException {
      throw const UnknownBotsFailure();
    } on TypeError {
      throw const UnknownBotsFailure();
    }
  }

  @override
  Future<Bot> clone({required String id, required String name}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/bots/$id/clone',
        data: BotCloneReq(name: name).toJson(),
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownBotsFailure();
      }
      return BotsMapper.botRespToEntity(BotResp.fromJson(body));
    } on BotsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownBotsFailure();
    } on TypeError {
      throw const UnknownBotsFailure();
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/bots/$id');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Traduce DioException a la jerarquía sellada de BotsFailure. Duplica el
  /// patrón de AuthFailure._mapDioException con los códigos de S04 (403 vs
  /// 401-de-login). Regla de tres: refactor a un helper compartido en el
  /// próximo feature que lo necesite.
  ///
  /// `versionConflict` rige el 409 POR-ENDPOINT: en el PUT (CAS) un 409 es
  /// conflicto de versión (`BotsConflictFailure`); en list/byId/create el 409
  /// (org no activa) no es accionable como conflicto y colapsa a genérico.
  BotsFailure _mapDioException(DioException e, {bool versionConflict = false}) {
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
        if (status == 404) return const BotsNotFoundFailure();
        if (status == 409 && versionConflict) {
          return const BotsConflictFailure();
        }
        if (status == 422) return const BotsInvalidCreateFailure();
        if (status >= 500 && status < 600) return const BotsServerFailure();
        return const UnknownBotsFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownBotsFailure();
    }
  }
}
