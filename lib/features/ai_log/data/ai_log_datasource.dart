import 'dart:convert';

import 'package:dio/dio.dart';

import '../domain/ai_log_repository.dart';
import '../domain/entities/ai_log_entry.dart';
import '../domain/failures/ai_log_failure.dart';

/// Puerto de datos del ai-log. La impl lanza `AiLogFailure` tipadas.
abstract interface class AiLogDatasource {
  Future<AiLogPageResult> page({
    required String botId,
    required String chatLid,
    int? before,
  });
}

/// `GET /sessions/:botId/:chatLid/ai-log?before=&limit=` (ADMIN+). El
/// chatLid viaja ENCODEADO en el path (los grupos llevan `@`).
class DioAiLogDatasource implements AiLogDatasource {
  DioAiLogDatasource(this._dio);

  final Dio _dio;

  @override
  Future<AiLogPageResult> page({
    required String botId,
    required String chatLid,
    int? before,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/sessions/$botId/${Uri.encodeComponent(chatLid)}/ai-log',
        queryParameters: <String, dynamic>{'before': ?before},
      );
      final body = res.data;
      if (body == null) {
        throw const AiLogUnknownFailure();
      }
      return _parsePage(body);
    } on AiLogFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDio(e);
    } on FormatException {
      throw const AiLogUnknownFailure();
    } on TypeError {
      throw const AiLogUnknownFailure();
    }
  }

  static AiLogPageResult _parsePage(Map<String, dynamic> body) {
    final rawItems = body['items'];
    final items = <AiLogEntry>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        items.add(_parseEntry(raw as Map<String, dynamic>));
      }
    }
    final nextBefore = body['nextBefore'];
    return AiLogPageResult(
      items: items,
      nextBefore: nextBefore is int ? nextBefore : null,
    );
  }

  static AiLogEntry _parseEntry(Map<String, dynamic> m) {
    final toolCalls = <AiToolCall>[];
    final rawCalls = m['toolCalls'];
    if (rawCalls is List) {
      for (final raw in rawCalls) {
        final c = raw as Map<String, dynamic>;
        toolCalls.add(
          AiToolCall(
            id: (c['id'] as String?) ?? '',
            name: (c['name'] as String?) ?? '',
            // arguments es JSON arbitrario: se re-encodea a string para
            // mostrarse tal cual, sin interpretarlo.
            argumentsJson: c['arguments'] == null
                ? ''
                : jsonEncode(c['arguments']),
          ),
        );
      }
    }
    return AiLogEntry(
      id: (m['id'] as num).toInt(),
      runId: (m['runId'] as String?) ?? '',
      role: AiLogRole.fromWire((m['role'] as String?) ?? ''),
      content: (m['content'] as String?) ?? '',
      reasoning: (m['reasoning'] as String?) ?? '',
      toolCalls: toolCalls,
      toolCallId: (m['toolCallId'] as String?) ?? '',
      toolName: (m['toolName'] as String?) ?? '',
      model: (m['model'] as String?) ?? '',
      promptTokens: ((m['promptTokens'] as num?) ?? 0).toInt(),
      completionTokens: ((m['completionTokens'] as num?) ?? 0).toInt(),
      totalTokens: ((m['totalTokens'] as num?) ?? 0).toInt(),
      createdAt:
          DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static AiLogFailure _mapDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const AiLogNetworkFailure();
      case DioExceptionType.badResponse:
        if (e.response?.statusCode == 403) {
          return const AiLogForbiddenFailure();
        }
        return const AiLogUnknownFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const AiLogUnknownFailure();
    }
  }
}

/// Repo trivial: delega al datasource (sin cache local).
class AiLogRepositoryImpl implements AiLogRepository {
  AiLogRepositoryImpl({required AiLogDatasource datasource}) : _ds = datasource;

  final AiLogDatasource _ds;

  @override
  Future<AiLogPageResult> page({
    required String botId,
    required String chatLid,
    int? before,
  }) => _ds.page(botId: botId, chatLid: chatLid, before: before);
}
