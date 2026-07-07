import 'package:dio/dio.dart';

import '../../domain/entities/org_branding.dart';
import '../../domain/failures/org_branding_failure.dart';
import '../dto/org_branding_dto.dart';
import '../mappers/org_branding_mapper.dart';

/// Puerto de datos de `/workspace/organization/branding` (ADMIN+). Las impls
/// lanzan `OrgBrandingFailure` tipadas; nunca DioException cruda.
abstract interface class OrgBrandingDatasource {
  Future<OrgBranding> get();
  Future<void> setLogo(String mediaRef);
  Future<void> reset();
}

class DioOrgBrandingDatasource implements OrgBrandingDatasource {
  const DioOrgBrandingDatasource(this._dio);

  static const _path = '/workspace/organization/branding';

  final Dio _dio;

  @override
  Future<OrgBranding> get() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(_path);
      final body = res.data;
      if (body == null) {
        throw const UnknownOrgBrandingFailure();
      }
      return OrgBrandingMapper.respToEntity(OrgBrandingResp.fromJson(body));
    } on OrgBrandingFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownOrgBrandingFailure();
    } on TypeError {
      throw const UnknownOrgBrandingFailure();
    }
  }

  @override
  Future<void> setLogo(String mediaRef) async {
    try {
      await _dio.put<void>(
        '$_path/logo',
        data: <String, dynamic>{'logo_media_ref': mediaRef},
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> reset() async {
    try {
      await _dio.delete<void>(_path);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  OrgBrandingFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const OrgBrandingNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const OrgBrandingForbiddenFailure();
        if (status == 422) return const OrgBrandingInvalidFailure();
        if (status >= 500 && status < 600) {
          return const OrgBrandingServerFailure();
        }
        return const UnknownOrgBrandingFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownOrgBrandingFailure();
    }
  }
}
