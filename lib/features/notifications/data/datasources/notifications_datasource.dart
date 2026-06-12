import 'package:dio/dio.dart';

import '../../domain/entities/notification_inbox_item.dart';
import '../../domain/entities/notification_preference.dart';
import '../../domain/failures/notifications_failure.dart';
import '../dto/notification_dto.dart';
import '../mappers/notification_mapper.dart';

abstract interface class NotificationsDatasource {
  Future<List<NotificationPreference>> listPreferences();

  Future<List<NotificationPreference>> savePreferences(
    List<NotificationPreference> preferences,
  );

  Future<List<NotificationInboxItem>> listInbox({required bool unreadOnly});

  Future<void> markRead(String id);

  Future<void> markAllRead();

  Future<void> registerPushToken({
    required String deviceId,
    required String fcmToken,
    required String platform,
  });

  Future<void> unregisterPushToken({required String deviceId});
}

class DioNotificationsDatasource implements NotificationsDatasource {
  DioNotificationsDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<NotificationPreference>> listPreferences() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/notification-preferences',
      );
      return _preferencesFromBody(res.data);
    } on NotificationsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownNotificationsFailure();
    } on TypeError {
      throw const UnknownNotificationsFailure();
    }
  }

  @override
  Future<List<NotificationPreference>> savePreferences(
    List<NotificationPreference> preferences,
  ) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/notification-preferences',
        data: <String, dynamic>{
          'preferences': preferences
              .map(NotificationsMapper.preferenceToWire)
              .toList(growable: false),
        },
      );
      return _preferencesFromBody(res.data);
    } on NotificationsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownNotificationsFailure();
    } on TypeError {
      throw const UnknownNotificationsFailure();
    }
  }

  @override
  Future<List<NotificationInboxItem>> listInbox({
    required bool unreadOnly,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/notifications',
        queryParameters: <String, dynamic>{
          'status': unreadOnly ? 'unread' : 'all',
        },
      );
      final body = res.data;
      if (body == null) throw const UnknownNotificationsFailure();
      final items = body['items'] as List<dynamic>;
      return _skipUnknown(
        items.cast<Map<String, dynamic>>().map(NotificationInboxResp.fromJson),
        NotificationsMapper.inboxRespToEntity,
      );
    } on NotificationsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownNotificationsFailure();
    } on TypeError {
      throw const UnknownNotificationsFailure();
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _dio.put<void>('/notifications/$id/read');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> markAllRead() async {
    try {
      await _dio.put<void>('/notifications/read-all');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> registerPushToken({
    required String deviceId,
    required String fcmToken,
    required String platform,
  }) async {
    try {
      await _dio.post<void>(
        '/push/register',
        data: <String, dynamic>{
          'deviceId': deviceId,
          'fcmToken': fcmToken,
          'platform': platform,
        },
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> unregisterPushToken({required String deviceId}) async {
    try {
      await _dio.delete<void>(
        '/push/token',
        data: <String, dynamic>{'deviceId': deviceId},
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  List<NotificationPreference> _preferencesFromBody(
    Map<String, dynamic>? body,
  ) {
    if (body == null) throw const UnknownNotificationsFailure();
    final items = body['items'] as List<dynamic>;
    return _skipUnknown(
      items.cast<Map<String, dynamic>>().map(
        NotificationPreferenceResp.fromJson,
      ),
      NotificationsMapper.preferenceRespToEntity,
    );
  }

  /// Mapea saltando las entradas con enums desconocidos: un backend más
  /// nuevo (eventType futuro) degrada esa fila, no la pantalla entera.
  static List<E> _skipUnknown<D, E>(Iterable<D> dtos, E Function(D) map) {
    final out = <E>[];
    for (final d in dtos) {
      try {
        out.add(map(d));
      } on FormatException {
        // Entrada de un release futuro: se omite.
      }
    }
    return out;
  }

  NotificationsFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NotificationsTimeoutFailure();
      case DioExceptionType.connectionError:
        return const NotificationsNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const NotificationsForbiddenFailure();
        if (status == 422) return const NotificationsInvalidFailure();
        if (status >= 500 && status < 600) {
          return const NotificationsServerFailure();
        }
        return const UnknownNotificationsFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownNotificationsFailure();
    }
  }
}
