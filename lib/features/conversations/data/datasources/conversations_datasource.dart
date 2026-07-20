import 'package:dio/dio.dart';

import '../../domain/entities/conversations_page.dart';
import '../../domain/entities/inbox_query.dart';
import '../../domain/failures/conversations_failure.dart';
import '../dto/conversation_dto.dart';
import '../mappers/conversations_mapper.dart';

abstract interface class ConversationsDatasource {
  Future<ConversationsPage> list(InboxQuery query);
}

class DioConversationsDatasource implements ConversationsDatasource {
  DioConversationsDatasource(this._dio);

  final Dio _dio;

  @override
  Future<ConversationsPage> list(InboxQuery query) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_pathFor(query));
      final body = response.data;
      if (body == null) throw const UnknownConversationsFailure();
      final page = ConversationsPageResp.fromJson(body);
      return ConversationsPage(
        items: page.items
            .map(ConversationsMapper.respToEntity)
            .toList(growable: false),
        nextCursor: page.nextCursor,
      );
    } on ConversationsFailure {
      rethrow;
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on FormatException {
      throw const UnknownConversationsFailure();
    } on ArgumentError {
      throw const UnknownConversationsFailure();
    } on TypeError {
      throw const UnknownConversationsFailure();
    }
  }

  String _pathFor(InboxQuery query) {
    final parts = <String>[];
    final search = query.search.trim();
    if (search.isNotEmpty) parts.add('q=${Uri.encodeQueryComponent(search)}');
    parts.add('status=${query.status.wireName}');
    if (query.botId case final botId?) {
      parts.add('botId=${Uri.encodeQueryComponent(botId)}');
    }
    if (query.labelId case final labelId?) {
      parts.add('labelId=${Uri.encodeQueryComponent(labelId)}');
    }
    if (query.cursor case final cursor?) {
      parts.add('cursor=${Uri.encodeQueryComponent(cursor)}');
    }
    parts.add('limit=${query.limit}');
    return '/inbox/conversations?${parts.join('&')}';
  }

  ConversationsFailure _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ConversationsTimeoutFailure();
      case DioExceptionType.connectionError:
        return const ConversationsNetworkFailure();
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        if (status == 403) return const ConversationsForbiddenFailure();
        if (status == 422) return const ConversationsInvalidQueryFailure();
        if (status >= 500 && status < 600) {
          return const ConversationsServerFailure();
        }
        return const UnknownConversationsFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownConversationsFailure();
    }
  }
}
