import 'package:dio/dio.dart';

import '../../domain/entities/monitor_event.dart';

/// Lectura best-effort que REUSA los endpoints ai-log existentes para hidratar
/// el monitor a mitad de una corrida: descubre el run activo y trae lo que ya
/// hizo, mapeado a [MonitorEvent]. No abre ningún canal nuevo en el backend.
abstract interface class MonitorCatchupDatasource {
  /// Run más reciente del chat (id + cuándo), o `null` si no hay log o el id es
  /// vacío (filas históricas pre-migración). Best-effort: cualquier fallo → null
  /// (no hidratar nunca debe derribar el hilo).
  Future<({String runId, DateTime at})?> activeRun(String botId, String chatLid);

  /// Eventos YA persistidos de una corrida (assistant→aiTurn, tool→aiTool; user
  /// omitido), en el orden ascendente que entrega el log.
  Future<List<MonitorEvent>> catchup(String botId, String chatLid, String runId);
}

/// Reusa `GET /sessions/:botId/:chatLid/ai-log` (ADMIN+): `?limit=1` descubre el
/// run activo y `?run=` trae sus entries. El chatLid viaja encodeado (grupos `@`).
class DioMonitorCatchupDatasource implements MonitorCatchupDatasource {
  DioMonitorCatchupDatasource(this._dio);

  final Dio _dio;

  String _path(String botId, String chatLid) =>
      '/sessions/$botId/${Uri.encodeComponent(chatLid)}/ai-log';

  @override
  Future<({String runId, DateTime at})?> activeRun(
    String botId,
    String chatLid,
  ) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        _path(botId, chatLid),
        queryParameters: <String, dynamic>{'limit': 1},
      );
      final items = res.data?['items'];
      if (items is! List || items.isEmpty) return null;
      final first = items.first as Map<String, dynamic>;
      final runId = (first['runId'] as String?) ?? '';
      if (runId.isEmpty) return null;
      final at = DateTime.tryParse(
        (first['createdAt'] as String?) ?? '',
      )?.toUtc();
      if (at == null) return null;
      return (runId: runId, at: at);
    } on Object {
      return null;
    }
  }

  @override
  Future<List<MonitorEvent>> catchup(
    String botId,
    String chatLid,
    String runId,
  ) async {
    final res = await _dio.get<Map<String, dynamic>>(
      _path(botId, chatLid),
      queryParameters: <String, dynamic>{'run': runId},
    );
    final raw = res.data?['items'];
    final out = <MonitorEvent>[];
    if (raw is! List) return out;
    for (final item in raw) {
      final m = item as Map<String, dynamic>;
      final role = (m['role'] as String?) ?? '';
      final at =
          DateTime.tryParse((m['createdAt'] as String?) ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final rid = (m['runId'] as String?) ?? runId;
      if (role == 'assistant') {
        out.add(
          MonitorEvent(
            kind: MonitorEventKind.aiTurn,
            topic: 'ai.turn',
            at: at,
            runId: rid,
            model: (m['model'] as String?) ?? '',
            tokensIn: ((m['promptTokens'] as num?) ?? 0).toInt(),
            tokensOut: ((m['completionTokens'] as num?) ?? 0).toInt(),
          ),
        );
      } else if (role == 'tool') {
        out.add(
          MonitorEvent(
            kind: MonitorEventKind.aiTool,
            topic: 'ai.tool',
            at: at,
            runId: rid,
            toolName: (m['toolName'] as String?) ?? '',
          ),
        );
      }
      // user / unknown: no son actividad del bot que el timeline pinte.
    }
    return out;
  }
}
