import 'package:dio/dio.dart';

import '../domain/ai_ledger_repository.dart';
import '../domain/entities/ledger_action.dart';
import '../domain/failures/ai_ledger_failure.dart';

/// Puerto de datos de la bitácora. La impl lanza `AiLedgerFailure` tipadas.
abstract interface class AiLedgerDatasource {
  Future<AiLedgerPageResult> page({
    required String botId,
    required String chatLid,
    int? before,
  });
}

/// `GET /sessions/:botId/:chatLid/ai-ledger?before=` (ADMIN+). El chatLid viaja
/// ENCODEADO en el path (los grupos llevan `@`). Espejo de DioAiLogDatasource.
class DioAiLedgerDatasource implements AiLedgerDatasource {
  DioAiLedgerDatasource(this._dio);

  final Dio _dio;

  @override
  Future<AiLedgerPageResult> page({
    required String botId,
    required String chatLid,
    int? before,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/sessions/$botId/${Uri.encodeComponent(chatLid)}/ai-ledger',
        queryParameters: <String, dynamic>{'before': ?before},
      );
      final body = res.data;
      if (body == null) {
        throw const AiLedgerUnknownFailure();
      }
      return _parsePage(body);
    } on AiLedgerFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDio(e);
    } on FormatException {
      throw const AiLedgerUnknownFailure();
    } on TypeError {
      throw const AiLedgerUnknownFailure();
    }
  }

  static AiLedgerPageResult _parsePage(Map<String, dynamic> body) {
    final rawItems = body['items'];
    final items = <LedgerAction>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        items.add(_parseItem(raw as Map<String, dynamic>));
      }
    }
    final nextBefore = body['nextBefore'];
    return AiLedgerPageResult(
      items: items,
      nextBefore: nextBefore is int ? nextBefore : null,
    );
  }

  static LedgerAction _parseItem(Map<String, dynamic> m) => LedgerAction(
    id: (m['id'] as num).toInt(),
    runId: (m['runId'] as String?) ?? '',
    toolName: (m['toolName'] as String?) ?? '',
    action: (m['action'] as String?) ?? '',
    detail: (m['detail'] as String?) ?? '',
    createdAt:
        DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  static AiLedgerFailure _mapDio(DioException e) {
    if (e.type == DioExceptionType.badResponse &&
        e.response?.statusCode == 403) {
      return const AiLedgerForbiddenFailure();
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const AiLedgerNetworkFailure();
      default:
        return const AiLedgerUnknownFailure();
    }
  }
}

/// Impl del repo: delega al datasource, sin caché.
class AiLedgerRepositoryImpl implements AiLedgerRepository {
  AiLedgerRepositoryImpl({required AiLedgerDatasource datasource})
    : _ds = datasource;

  final AiLedgerDatasource _ds;

  @override
  Future<AiLedgerPageResult> page({
    required String botId,
    required String chatLid,
    int? before,
  }) => _ds.page(botId: botId, chatLid: chatLid, before: before);
}
