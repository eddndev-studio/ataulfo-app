import 'package:dio/dio.dart';

import '../domain/entities/execution.dart';
import '../domain/execution_repository.dart';
import '../domain/failures/execution_failure.dart';

/// Puerto de datos del historial de ejecuciones. La impl lanza
/// `ExecutionFailure` tipadas.
abstract interface class ExecutionsDatasource {
  Future<List<Execution>> listBySession({
    required String botId,
    required String chatLid,
  });
}

/// `GET /sessions/:botId/:chatLid/executions` (ADMIN+). El chatLid viaja
/// ENCODEADO en el path (los grupos llevan `@`). La respuesta es el envelope
/// `{items:[...]}` SIN paginación.
class DioExecutionsDatasource implements ExecutionsDatasource {
  DioExecutionsDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<Execution>> listBySession({
    required String botId,
    required String chatLid,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/sessions/$botId/${Uri.encodeComponent(chatLid)}/executions',
      );
      final body = res.data;
      if (body == null) {
        throw const ExecutionUnknownFailure();
      }
      final rawItems = body['items'];
      final items = <Execution>[];
      if (rawItems is List) {
        for (final raw in rawItems) {
          items.add(_parse(raw as Map<String, dynamic>));
        }
      }
      return items;
    } on ExecutionFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDio(e);
    } on FormatException {
      throw const ExecutionUnknownFailure();
    } on TypeError {
      throw const ExecutionUnknownFailure();
    }
  }

  static Execution _parse(Map<String, dynamic> m) {
    final ended = m['endedAt'] as String?;
    return Execution(
      id: (m['id'] as String?) ?? '',
      botId: (m['botId'] as String?) ?? '',
      chatLid: (m['chatLid'] as String?) ?? '',
      flowId: (m['flowId'] as String?) ?? '',
      templateId: (m['templateId'] as String?) ?? '',
      status: ExecutionStatus.fromWire((m['status'] as String?) ?? ''),
      error: (m['error'] as String?) ?? '',
      currentStep: ((m['currentStep'] as num?) ?? 0).toInt(),
      startedAt:
          DateTime.tryParse((m['startedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      endedAt: (ended != null && ended.isNotEmpty)
          ? DateTime.tryParse(ended)
          : null,
    );
  }

  static ExecutionFailure _mapDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const ExecutionNetworkFailure();
      case DioExceptionType.badResponse:
        if (e.response?.statusCode == 403) {
          return const ExecutionForbiddenFailure();
        }
        return const ExecutionUnknownFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const ExecutionUnknownFailure();
    }
  }
}

/// Repo trivial: delega al datasource (sin cache local).
class ExecutionRepositoryImpl implements ExecutionRepository {
  ExecutionRepositoryImpl({required ExecutionsDatasource datasource})
    : _ds = datasource;

  final ExecutionsDatasource _ds;

  @override
  Future<List<Execution>> listBySession({
    required String botId,
    required String chatLid,
  }) => _ds.listBySession(botId: botId, chatLid: chatLid);
}
