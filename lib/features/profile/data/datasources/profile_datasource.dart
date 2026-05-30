import 'package:dio/dio.dart';

import '../../domain/entities/chat_profile.dart';
import '../../domain/failures/profile_failure.dart';
import '../dto/profile_dto.dart';
import '../mappers/profile_mapper.dart';

/// Puerto de datos del perfil de un chat. Las implementaciones lanzan
/// `ProfileFailure` tipadas; nunca DioException cruda.
abstract interface class ProfileDatasource {
  Future<ChatProfile> fetch(String botId, String chatLid);
}

class DioProfileDatasource implements ProfileDatasource {
  DioProfileDatasource(this._dio);

  final Dio _dio;

  @override
  Future<ChatProfile> fetch(String botId, String chatLid) async {
    try {
      // chatLid puede llevar `@` (grupos): se percent-encodea para el path,
      // igual que el datasource del hilo de mensajes.
      final res = await _dio.get<Map<String, dynamic>>(
        '/sessions/$botId/${Uri.encodeComponent(chatLid)}/profile',
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownProfileFailure();
      }
      return ProfileMapper.respToEntity(ProfileResp.fromJson(body));
    } on ProfileFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownProfileFailure();
    } on TypeError {
      throw const UnknownProfileFailure();
    }
  }

  ProfileFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ProfileTimeoutFailure();
      case DioExceptionType.connectionError:
        return const ProfileNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const ProfileForbiddenFailure();
        if (status == 404) return const ProfileNotFoundFailure();
        if (status >= 500 && status < 600) return const ProfileServerFailure();
        return const UnknownProfileFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownProfileFailure();
    }
  }
}
