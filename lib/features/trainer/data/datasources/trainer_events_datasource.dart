import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/network/sse/reconnecting_stream.dart';
import '../../../../core/network/sse/sse_parser.dart';
import '../../domain/entities/trainer_progress.dart';
import '../../domain/repositories/trainer_repositories.dart';

/// Implementación del puerto `TrainerEvents` sobre el stream SSE
/// `GET /templates/{templateId}/trainer/conversations/{id}/stream`, filtrado y
/// mapeado a `TrainerProgressEvent`. Solo progreso cosmético
/// (pensando/tool/completed/failed); el contenido del mensaje llega por el
/// POST/recarga, no por aquí.
class DioTrainerEventsDatasource implements TrainerEvents {
  DioTrainerEventsDatasource(this._dio);

  final Dio _dio;

  /// Topics del bus que pintan el indicador en vivo del turno.
  static const Set<String> _topics = <String>{
    'trainer_agent.thinking',
    'trainer_agent.tool',
    'trainer_agent.completed',
    'trainer_agent.failed',
  };

  @override
  Stream<TrainerProgressEvent> progress(
    String templateId,
    String conversationId,
  ) => reconnectingStream<TrainerProgressEvent>(
    () => connectOnce(templateId, conversationId),
  );

  /// Una sola conexión SSE: abre el stream del hilo, parsea/filtra/mapea los
  /// frames a `TrainerProgressEvent` y termina cuando el backend cierra o falla.
  /// `progress` la envuelve con reconexión; aislarla mantiene el parseo
  /// determinista y testeable sin el loop de reconexión.
  Stream<TrainerProgressEvent> connectOnce(
    String templateId,
    String conversationId,
  ) async* {
    final cancel = CancelToken();
    try {
      final res = await _dio.get<ResponseBody>(
        '/templates/$templateId/trainer/conversations/$conversationId/stream',
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          // SSE es long-lived: el receiveTimeout lo mataría en cada pausa entre
          // eventos. El heartbeat del backend mantiene viva la conexión.
          receiveTimeout: Duration.zero,
          headers: <String, String>{'Accept': 'text/event-stream'},
        ),
      );
      final body = res.data;
      if (body == null) return;
      await for (final ev in decodeSseEvents(body.stream)) {
        if (!_topics.contains(ev.event)) continue;
        final parsed = _tryParse(ev.data);
        if (parsed != null) yield parsed;
      }
    } finally {
      cancel.cancel();
    }
  }

  /// Traduce el `data` (taWire) a `TrainerProgressEvent`. JSON roto o canónico
  /// ausente (kind/conversationId) ⇒ null y se omite: el progreso es cosmético,
  /// un frame malo no debe derribar el indicador.
  TrainerProgressEvent? _tryParse(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final kind = json['kind'] as String?;
      final conversationId = json['conversationId'] as String?;
      if (kind == null || conversationId == null) return null;
      return TrainerProgressEvent(
        kind: kind,
        conversationId: conversationId,
        at:
            DateTime.tryParse(json['at'] as String? ?? '')?.toUtc() ??
            DateTime.now().toUtc(),
        runId: json['runId'] as String? ?? '',
        iteration: json['iteration'] as int? ?? 0,
        model: json['model'] as String? ?? '',
        toolName: json['toolName'] as String? ?? '',
        toolError: json['toolError'] as bool? ?? false,
        error: json['error'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
