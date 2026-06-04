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

  /// `PUT /workspace/members/{id}/role` con body `{role}`. 204 ⇒ completa.
  Future<void> changeRole(String membershipId, String role);

  /// `DELETE /workspace/members/{id}`. 204 ⇒ completa.
  Future<void> removeMember(String membershipId);
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

  @override
  Future<void> changeRole(String membershipId, String role) async {
    try {
      await _dio.put<void>(
        '/workspace/members/$membershipId/role',
        data: <String, dynamic>{'role': role},
      );
    } on DioException catch (e) {
      // En change-role el único 403 del servicio es el self-upgrade.
      throw _mapMutationException(
        e,
        on403: const MembersSelfRoleUpgradeFailure(),
      );
    }
  }

  @override
  Future<void> removeMember(String membershipId) async {
    try {
      await _dio.delete<void>('/workspace/members/$membershipId');
    } on DioException catch (e) {
      // RemoveMember no tiene 403 de servicio; un 403 sólo vendría del guard de
      // rol de la ruta, así que se mapea al genérico (no a self-upgrade).
      throw _mapMutationException(e, on403: const MembersForbiddenFailure());
    }
  }

  /// Mapeo del listado: 403 = guard de rol, 409 = guard de org activa.
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

  /// Mapeo de las mutaciones. A diferencia del listado, 409 = sole-owner (el
  /// caller siempre tiene org activa al llegar aquí) y 404 = miembro inexistente.
  /// El significado del 403 depende del endpoint, de ahí [on403].
  MembersFailure _mapMutationException(
    DioException e, {
    required MembersFailure on403,
  }) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const MembersTimeoutFailure();
      case DioExceptionType.connectionError:
        return const MembersNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return on403;
        if (status == 404) return const MembersNotFoundFailure();
        if (status == 409) return const MembersSoleOwnerFailure();
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
