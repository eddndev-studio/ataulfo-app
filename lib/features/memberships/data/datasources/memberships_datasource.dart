import 'package:dio/dio.dart';

import '../../domain/entities/membership.dart';
import '../../domain/failures/memberships_failure.dart';
import '../dto/membership_dto.dart';
import '../mappers/memberships_mapper.dart';

/// Puerto de datos para `GET /auth/memberships` (S02 post-`/auth/me`-email).
///
/// Las implementaciones lanzan `MembershipsFailure` tipadas; nunca
/// DioException cruda. El repositorio y el bloc consumen failures de
/// dominio.
abstract interface class MembershipsDatasource {
  /// `GET /auth/memberships` — lista de orgs del operador decoradas con
  /// `org_name`. 200 con `[]` es legítimo (el caller perdió memberships
  /// activas); el llamador lo interpreta sin convertirlo en failure.
  /// Bearer lo inyecta el interceptor.
  Future<List<Membership>> list();
}

class DioMembershipsDatasource implements MembershipsDatasource {
  DioMembershipsDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<Membership>> list() async {
    try {
      final res = await _dio.get<List<dynamic>>('/auth/memberships');
      final body = res.data;
      if (body == null) {
        throw const UnknownMembershipsFailure();
      }
      return body
          .cast<Map<String, dynamic>>()
          .map(MembershipResp.fromJson)
          .map(MembershipsMapper.respToEntity)
          .toList(growable: false);
    } on MembershipsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownMembershipsFailure();
    } on TypeError {
      // `cast<Map<String,dynamic>>` puede romper si el wire mete un tipo
      // inesperado; el contrato dice array de objetos.
      throw const UnknownMembershipsFailure();
    }
  }

  /// Traduce DioException a la jerarquía sellada del feature. Sin variante
  /// 404: el endpoint no la emite (200 con [] cubre "sin orgs"). Sin 422:
  /// es read-only.
  MembershipsFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const MembershipsTimeoutFailure();
      case DioExceptionType.connectionError:
        return const MembershipsNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const MembershipsForbiddenFailure();
        if (status >= 500 && status < 600) {
          return const MembershipsServerFailure();
        }
        return const UnknownMembershipsFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownMembershipsFailure();
    }
  }
}
