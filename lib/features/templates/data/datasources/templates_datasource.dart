import 'package:dio/dio.dart';

import '../../domain/entities/template.dart';
import '../../domain/failures/templates_failure.dart';
import '../dto/template_dto.dart';
import '../mappers/templates_mapper.dart';

/// Puerto de datos para los endpoints de Template (S03).
///
/// Las implementaciones lanzan `TemplatesFailure` tipadas; nunca
/// DioException cruda. El repositorio y el bloc consumen failures de
/// dominio. Drift de contrato del backend (proveedor IA desconocido) NO
/// se mapea a una failure — propaga el `ArgumentError` del enum fail-loud
/// para detectar el bug en boot, no degradarlo a un spinner reintentable.
abstract interface class TemplatesDatasource {
  /// `GET /templates` org-scoped. El AuthInterceptor inyecta el Bearer;
  /// aquí no se gestiona. RBAC del backend rechaza con 403 si el rol no
  /// alcanza (CRUD de Template = ADMIN+).
  Future<List<Template>> list();

  /// `GET /templates/:id` org-scoped. 404 si el id no existe en la org
  /// del operador — mapea a `TemplatesNotFoundFailure`.
  Future<Template> byId(String id);
}

class DioTemplatesDatasource implements TemplatesDatasource {
  DioTemplatesDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<Template>> list() async {
    try {
      final res = await _dio.get<List<dynamic>>('/templates');
      final body = res.data;
      if (body == null) {
        throw const UnknownTemplatesFailure();
      }
      return body
          .cast<Map<String, dynamic>>()
          .map(TemplateResp.fromJson)
          .map(TemplatesMapper.templateRespToEntity)
          .toList(growable: false);
    } on TemplatesFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownTemplatesFailure();
    } on TypeError {
      // `cast<Map<String,dynamic>>` puede romper si el wire mete un tipo
      // inesperado; el contrato dice array de objetos.
      throw const UnknownTemplatesFailure();
    }
  }

  @override
  Future<Template> byId(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/templates/$id');
      final body = res.data;
      if (body == null) {
        throw const UnknownTemplatesFailure();
      }
      return TemplatesMapper.templateRespToEntity(TemplateResp.fromJson(body));
    } on TemplatesFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownTemplatesFailure();
    } on TypeError {
      throw const UnknownTemplatesFailure();
    }
  }

  /// Traduce DioException a la jerarquía sellada de TemplatesFailure.
  /// Duplica el patrón de BotsFailure._mapDioException; cuando aterrice
  /// la tercera feature con el mismo patrón, extraer a un helper
  /// compartido en `core/network/` (regla de tres).
  TemplatesFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TemplatesTimeoutFailure();
      case DioExceptionType.connectionError:
        return const TemplatesNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const TemplatesForbiddenFailure();
        if (status == 404) return const TemplatesNotFoundFailure();
        if (status >= 500 && status < 600) {
          return const TemplatesServerFailure();
        }
        return const UnknownTemplatesFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownTemplatesFailure();
    }
  }
}
