import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/network/sse/reconnecting_stream.dart';
import '../../../../core/network/sse/sse_parser.dart';
import '../../domain/entities/pa_progress.dart';
import '../dto/pa_dtos.dart';

/// Puerto de realtime del turno del asistente de plataforma: el stream SSE
/// `GET /platform-agent/conversations/{id}/stream`, filtrado y mapeado a
/// `PaProgressEvent`. Solo progreso cosmético (pensando/tool/completed/failed);
/// el contenido del mensaje llega por el POST/recarga, no por aquí.
abstract interface class PlatformAgentEventsDatasource {
  /// Progreso en vivo del hilo. Perdurable: si la conexión cae se reconecta
  /// sola con backoff hasta que el consumidor cancela. Un frame malformado se
  /// omite sin derribar el stream.
  Stream<PaProgressEvent> progress(String conversationId);
}

class DioPlatformAgentEventsDatasource
    implements PlatformAgentEventsDatasource {
  DioPlatformAgentEventsDatasource(this._dio);

  final Dio _dio;

  /// Topics del bus que pintan el indicador en vivo del turno.
  static const Set<String> _topics = <String>{
    'platform_agent.thinking',
    'platform_agent.tool',
    'platform_agent.completed',
    'platform_agent.failed',
  };

  @override
  Stream<PaProgressEvent> progress(String conversationId) =>
      reconnectingStream<PaProgressEvent>(() => connectOnce(conversationId));

  /// Una sola conexión SSE: abre el stream del hilo, parsea/filtra/mapea los
  /// frames a `PaProgressEvent` y termina cuando el backend cierra o falla.
  /// `progress` la envuelve con reconexión; aislarla mantiene el parseo
  /// determinista y testeable sin el loop de reconexión.
  Stream<PaProgressEvent> connectOnce(String conversationId) async* {
    final cancel = CancelToken();
    try {
      final res = await _dio.get<ResponseBody>(
        '/platform-agent/conversations/$conversationId/stream',
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          // SSE es long-lived: el receiveTimeout lo mataría en cada pausa
          // entre eventos. El heartbeat del backend mantiene viva la conexión.
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

  /// Traduce el `data` (paWire) a `PaProgressEvent`. JSON roto o canónico
  /// ausente (kind/conversationId) ⇒ null y se omite: el progreso es
  /// cosmético, un frame malo no debe derribar el indicador.
  PaProgressEvent? _tryParse(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return PaProgressEventDto.fromJson(json).toEntity();
    } catch (_) {
      return null;
    }
  }
}
