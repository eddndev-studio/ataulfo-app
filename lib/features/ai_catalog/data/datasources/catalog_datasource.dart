import 'package:dio/dio.dart';

import '../../domain/entities/catalog.dart';
import '../../domain/failures/catalog_failure.dart';
import '../dto/catalog_dto.dart';
import '../mappers/catalog_mapper.dart';

/// Puerto de datos para `GET /ai/catalog` (S12 RF#3).
///
/// Las implementaciones lanzan `CatalogFailure` tipadas; nunca DioException
/// cruda. El repositorio y el bloc consumen failures de dominio.
abstract interface class CatalogDatasource {
  /// `GET /ai/catalog` — tabla estática de proveedores y modelos del Motor
  /// IA. Bearer lo inyecta el interceptor. El endpoint viaja envuelto en
  /// adminOnly: WORKER/SUPERVISOR reciben 403.
  Future<Catalog> fetch();
}

class DioCatalogDatasource implements CatalogDatasource {
  DioCatalogDatasource(this._dio);

  final Dio _dio;

  @override
  Future<Catalog> fetch() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/ai/catalog');
      final body = res.data;
      if (body == null) {
        throw const UnknownCatalogFailure();
      }
      final dto = CatalogResp.fromJson(body);
      return CatalogMapper.respToEntity(dto);
    } on CatalogFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownCatalogFailure();
    } on TypeError {
      // Defensa contra wires con tipos inesperados (p.ej. `models` mapeado
      // como objeto en lugar de lista); el contrato dice array de objetos.
      throw const UnknownCatalogFailure();
    }
  }

  /// Traduce DioException a la jerarquía sellada del feature. Sin variantes
  /// 404 (la tabla siempre existe) ni 422 (read-only sin body).
  CatalogFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const CatalogTimeoutFailure();
      case DioExceptionType.connectionError:
        return const CatalogNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const CatalogForbiddenFailure();
        if (status >= 500 && status < 600) {
          return const CatalogServerFailure();
        }
        return const UnknownCatalogFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownCatalogFailure();
    }
  }
}
