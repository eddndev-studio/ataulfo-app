import 'package:dio/dio.dart';

import '../../domain/entities/created_invitation.dart';
import '../../domain/entities/invitation.dart';
import '../../domain/failures/invitations_failure.dart';
import '../dto/invitation_dto.dart';
import '../mappers/invitations_mapper.dart';

/// Puerto de datos de invitaciones. Lanza `InvitationsFailure` tipadas, nunca
/// DioException cruda.
abstract interface class InvitationsDatasource {
  /// `GET /workspace/invitations` — historial. 200 con `[]` legítimo.
  Future<List<Invitation>> list();

  /// `POST /workspace/invitations` con body `{email, role}`. 201 ⇒ devuelve el
  /// [CreatedInvitation] (token crudo a compartir + si el correo salió).
  Future<CreatedInvitation> create(String email, String role);

  /// `DELETE /workspace/invitations/{id}`. 204 ⇒ completa.
  Future<void> cancel(String id);
}

class DioInvitationsDatasource implements InvitationsDatasource {
  DioInvitationsDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<Invitation>> list() async {
    try {
      final res = await _dio.get<List<dynamic>>('/workspace/invitations');
      final body = res.data;
      if (body == null) {
        throw const UnknownInvitationsFailure();
      }
      return body
          .cast<Map<String, dynamic>>()
          .map(InvitationResp.fromJson)
          .map(InvitationsMapper.respToEntity)
          .toList(growable: false);
    } on InvitationsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapList(e);
    } on FormatException {
      throw const UnknownInvitationsFailure();
    } on TypeError {
      throw const UnknownInvitationsFailure();
    }
  }

  @override
  Future<CreatedInvitation> create(String email, String role) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/workspace/invitations',
        data: <String, dynamic>{'email': email, 'role': role},
      );
      final body = res.data;
      if (body == null) {
        // 201 sin cuerpo (backend previo): la invitación se creó pero no hay
        // token que compartir — degrada honesto a "revisa el correo".
        return CreatedInvitation(email: email, token: null, emailSent: true);
      }
      final resp = InvitationResp.fromJson(body);
      return CreatedInvitation(
        email: resp.email,
        token: resp.token,
        emailSent: resp.emailSent,
      );
    } on InvitationsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapCreate(e);
    } on FormatException {
      throw const UnknownInvitationsFailure();
    } on TypeError {
      throw const UnknownInvitationsFailure();
    }
  }

  @override
  Future<void> cancel(String id) async {
    try {
      await _dio.delete<void>('/workspace/invitations/$id');
    } on DioException catch (e) {
      throw _mapCancel(e);
    }
  }

  /// Listado: 403 = guard de rol; 5xx = server. (409 sólo sería NoActiveOrg,
  /// inalcanzable porque el router desvía sin org activa.)
  InvitationsFailure _mapList(DioException e) =>
      _transport(e) ??
      switch (e.response?.statusCode ?? 0) {
        403 => const InvitationsForbiddenFailure(),
        >= 500 && < 600 => const InvitationsServerFailure(),
        _ => const UnknownInvitationsFailure(),
      };

  /// Creación: 409 = duplicada PENDING (o ya miembro); 422 = email/rol inválidos.
  /// 5xx puede significar fila guardada + correo fallido (sin reenvío).
  InvitationsFailure _mapCreate(DioException e) =>
      _transport(e) ??
      switch (e.response?.statusCode ?? 0) {
        403 => const InvitationsForbiddenFailure(),
        409 => const InvitationsDuplicateFailure(),
        422 => const InvitationsValidationFailure(),
        >= 500 && < 600 => const InvitationsServerFailure(),
        _ => const UnknownInvitationsFailure(),
      };

  /// Cancelación: 404 = ya no existe; 410 = ya consumida/expirada (no
  /// cancelable). Ambas implican que la lista local quedó stale.
  InvitationsFailure _mapCancel(DioException e) =>
      _transport(e) ??
      switch (e.response?.statusCode ?? 0) {
        403 => const InvitationsForbiddenFailure(),
        404 => const InvitationsNotFoundFailure(),
        410 => const InvitationsGoneFailure(),
        >= 500 && < 600 => const InvitationsServerFailure(),
        _ => const UnknownInvitationsFailure(),
      };

  /// Fallos de transporte comunes a los tres métodos (timeout/red). `null` si
  /// el error es una respuesta del servidor, que cada método mapea por status.
  InvitationsFailure? _transport(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const InvitationsTimeoutFailure();
      case DioExceptionType.connectionError:
        return const InvitationsNetworkFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownInvitationsFailure();
      case DioExceptionType.badResponse:
        return null;
    }
  }
}
