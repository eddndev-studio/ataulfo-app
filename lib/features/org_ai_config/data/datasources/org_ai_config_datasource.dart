import 'package:dio/dio.dart';

import '../../../templates/data/mappers/templates_mapper.dart';
import '../../domain/entities/org_ai_config.dart';
import '../../domain/failures/org_ai_config_failure.dart';
import '../dto/org_ai_config_dto.dart';
import '../mappers/org_ai_config_mapper.dart';

/// Puerto de datos de `/org/ai-config` (ADMIN/OWNER). Las impls lanzan
/// `OrgAiConfigFailure` tipadas; nunca DioException cruda. Drift de contrato
/// (un provider/thinking del wire desconocido en `defaults`) propaga el
/// `ArgumentError` del enum fail-loud, no se degrada a una failure.
abstract interface class OrgAiConfigDatasource {
  Future<OrgAiConfig> get();
  Future<OrgAiConfig> update(OrgAiConfig config);
}

class DioOrgAiConfigDatasource implements OrgAiConfigDatasource {
  const DioOrgAiConfigDatasource(this._dio);

  final Dio _dio;

  @override
  Future<OrgAiConfig> get() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/org/ai-config');
      final body = res.data;
      if (body == null) {
        throw const UnknownOrgAiConfigFailure();
      }
      return OrgAiConfigMapper.respToEntity(OrgAiConfigResp.fromJson(body));
    } on OrgAiConfigFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownOrgAiConfigFailure();
    } on TypeError {
      throw const UnknownOrgAiConfigFailure();
    }
  }

  @override
  Future<OrgAiConfig> update(OrgAiConfig config) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/org/ai-config',
        data: <String, dynamic>{
          'hosts': config.hosts,
          'defaults': TemplatesMapper.aiConfigToWire(config.defaults),
        },
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownOrgAiConfigFailure();
      }
      return OrgAiConfigMapper.respToEntity(OrgAiConfigResp.fromJson(body));
    } on OrgAiConfigFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapMutationDioException(e);
    } on FormatException {
      throw const UnknownOrgAiConfigFailure();
    } on TypeError {
      throw const UnknownOrgAiConfigFailure();
    }
  }

  // En la mutación, 422 = config rechazada por el dominio del backend (host no
  // ofrecido / defaults inválidos) ⇒ Invalid; el resto cae al mapeo general.
  OrgAiConfigFailure _mapMutationDioException(DioException e) {
    if (e.type == DioExceptionType.badResponse &&
        e.response?.statusCode == 422) {
      return const OrgAiConfigInvalidFailure();
    }
    return _mapDioException(e);
  }

  OrgAiConfigFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const OrgAiConfigNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const OrgAiConfigForbiddenFailure();
        if (status == 422) return const OrgAiConfigInvalidFailure();
        if (status >= 500 && status < 600) {
          return const OrgAiConfigServerFailure();
        }
        return const UnknownOrgAiConfigFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownOrgAiConfigFailure();
    }
  }
}
