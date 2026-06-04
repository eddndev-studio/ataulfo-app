import 'package:dio/dio.dart';

import '../../domain/entities/member.dart';
import '../../domain/failures/members_failure.dart';
import '../dto/member_dto.dart';
import '../mappers/members_mapper.dart';

/// Puerto de datos para `GET /workspace/members`.
///
/// Las implementaciones lanzan `MembersFailure` tipadas; nunca DioException
/// cruda. El repositorio y el bloc consumen failures de dominio.
abstract interface class MembersDatasource {
  /// `GET /workspace/members` — miembros de la org activa. 200 con `[]` es
  /// legítimo; el llamador lo interpreta sin convertirlo en failure. Bearer y
  /// org activa los resuelve el backend desde el token.
  Future<List<Member>> list();
}

class DioMembersDatasource implements MembersDatasource {
  DioMembersDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<Member>> list() async {
    try {
      final res = await _dio.get<List<dynamic>>('/workspace/members');
      final body = res.data;
      if (body == null) {
        throw const UnknownMembersFailure();
      }
      return body
          .cast<Map<String, dynamic>>()
          .map(MemberResp.fromJson)
          .map(MembersMapper.respToEntity)
          .toList(growable: false);
    } on MembersFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownMembersFailure();
    } on TypeError {
      // `cast<Map<String,dynamic>>` puede romper si el wire mete un tipo
      // inesperado; el contrato dice array de objetos.
      throw const UnknownMembersFailure();
    }
  }

  /// Traduce DioException a la jerarquía sellada del feature. 403 lo emite el
  /// guard RequireRole(ADMIN+); 409 el guard RequireActiveOrg.
  MembersFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const MembersTimeoutFailure();
      case DioExceptionType.connectionError:
        return const MembersNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const MembersForbiddenFailure();
        if (status == 409) return const MembersNoActiveOrgFailure();
        if (status >= 500 && status < 600) {
          return const MembersServerFailure();
        }
        return const UnknownMembersFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownMembersFailure();
    }
  }
}
