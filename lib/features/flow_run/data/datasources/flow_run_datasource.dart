import 'package:dio/dio.dart';

import '../../domain/entities/runnable_flow.dart';
import '../../domain/failures/flow_run_failure.dart';

/// Puerto de datos del arranque manual de flujos (S11). Lanza `FlowRunFailure`
/// tipadas; nunca DioException cruda.
abstract interface class FlowRunDatasource {
  Future<List<RunnableFlow>> listRunnable(String botId);

  Future<String> run({
    required String botId,
    required String chatLid,
    required String flowId,
  });
}

class DioFlowRunDatasource implements FlowRunDatasource {
  DioFlowRunDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<RunnableFlow>> listRunnable(String botId) async {
    try {
      final res = await _dio.get<List<dynamic>>('/sessions/$botId/flows');
      final body = res.data;
      if (body == null) {
        throw const UnknownFlowRunFailure();
      }
      return body
          .map((e) {
            final m = (e as Map).cast<String, dynamic>();
            final id = m['id'];
            final name = m['name'];
            if (id is! String || name is! String) {
              throw const UnknownFlowRunFailure();
            }
            return RunnableFlow(id: id, name: name);
          })
          .toList(growable: false);
    } on FlowRunFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapList(e);
    } on TypeError {
      throw const UnknownFlowRunFailure();
    }
  }

  @override
  Future<String> run({
    required String botId,
    required String chatLid,
    required String flowId,
  }) async {
    try {
      // El chatLid (grupos con `@g.us`) se percent-encodea en el segmento.
      final res = await _dio.post<Map<String, dynamic>>(
        '/sessions/$botId/${Uri.encodeComponent(chatLid)}/flows/$flowId/run',
      );
      final id = res.data?['executionId'];
      if (id is! String) {
        throw const UnknownFlowRunFailure();
      }
      return id;
    } on FlowRunFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapRun(e);
    } on TypeError {
      throw const UnknownFlowRunFailure();
    }
  }

  FlowRunFailure _mapList(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const FlowRunTimeoutFailure();
      case DioExceptionType.connectionError:
        return const FlowRunNetworkFailure();
      case DioExceptionType.badResponse:
        final s = e.response?.statusCode ?? 0;
        if (s == 403) return const FlowRunForbiddenFailure();
        if (s == 404) return const FlowRunNotFoundFailure();
        if (s >= 500 && s < 600) return const FlowRunServerFailure();
        return const UnknownFlowRunFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownFlowRunFailure();
    }
  }

  FlowRunFailure _mapRun(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const FlowRunTimeoutFailure();
      case DioExceptionType.connectionError:
        return const FlowRunNetworkFailure();
      case DioExceptionType.badResponse:
        final s = e.response?.statusCode ?? 0;
        if (s == 403) return const FlowRunForbiddenFailure();
        if (s == 404) return const FlowRunNotFoundFailure();
        if (s == 423) return const FlowRunPausedFailure();
        if (s == 409) {
          final reason = _reasonOf(e.response?.data);
          return reason != null
              ? FlowRunBlockedFailure(reason)
              : const FlowRunConflictFailure();
        }
        if (s >= 500 && s < 600) return const FlowRunServerFailure();
        return const UnknownFlowRunFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownFlowRunFailure();
    }
  }

  /// Razón de gate del body de un 409 (`{reason}`); null si el 409 no la trae
  /// (conflicto neutro / doble-tap).
  String? _reasonOf(dynamic data) {
    if (data is Map) {
      final r = data['reason'];
      if (r is String && r.isNotEmpty) return r;
    }
    return null;
  }
}
