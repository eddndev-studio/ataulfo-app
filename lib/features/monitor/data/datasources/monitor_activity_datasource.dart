import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/network/sse/reconnecting_stream.dart';
import '../../../../core/network/sse/sse_parser.dart';
import '../../domain/entities/monitor_event.dart';

/// Puerto de la actividad EN VIVO del bot runtime de un chat: el stream SSE
/// `GET /sessions/{botId}/{chatLid}/ai-activity` (ADMIN+), mapeado a
/// `MonitorEvent`. El consumidor (cubit) lo inyecta detrás de esta interfaz —
/// no conoce el transporte.
abstract interface class MonitorActivityDatasource {
  /// Actividad del chat. Perdurable: si la conexión cae se reconecta sola con
  /// backoff hasta que el consumidor cancela. Un frame malformado se omite sin
  /// derribar el stream.
  Stream<MonitorEvent> activity(String botId, String chatLid);
}

/// Puerto de la actividad de TODOS los chats de un bot (tier OPERADOR, WORKER+):
/// el stream SSE `GET /bots/{botId}/ai-activity`, con el wire recortado (sin
/// PII). La bandeja lo usa para señalar qué chats necesitan atención. Interfaz
/// aparte de MonitorActivityDatasource para no tocar a sus consumidores.
abstract interface class MonitorBotActivityDatasource {
  /// Actividad del bot (todos sus chats). Mismas garantías que `activity`.
  Stream<MonitorEvent> botActivity(String botId);
}

class DioMonitorActivityDatasource
    implements MonitorActivityDatasource, MonitorBotActivityDatasource {
  DioMonitorActivityDatasource(this._dio);

  final Dio _dio;

  @override
  Stream<MonitorEvent> activity(
    String botId,
    String chatLid,
  ) => reconnectingStream<MonitorEvent>(
    () => _connect('/sessions/$botId/$chatLid/ai-activity', live: true),
    // Salud del SSE para el footer del hilo: el disconnect se emite al CAER el
    // feed (banner ON durante todo el hueco); el connected (desde _connect, tras
    // el handshake) lo APAGA aunque el bot esté inactivo. El reconnect adicional
    // cubre el arranque de cada reintento.
    reconnectMarker: _reconnectSentinel,
    disconnectMarker: _reconnectSentinel,
  );

  static MonitorEvent _reconnectSentinel() => MonitorEvent(
    kind: MonitorEventKind.reconnect,
    topic: '',
    at: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  static MonitorEvent _connectedSentinel() => MonitorEvent(
    kind: MonitorEventKind.connected,
    topic: '',
    at: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  @override
  Stream<MonitorEvent> botActivity(String botId) =>
      reconnectingStream<MonitorEvent>(
        () => _connect('/bots/$botId/ai-activity'),
      );

  /// [live] marca el feed por-chat: emite un sentinel `connected` tras el
  /// handshake HTTP, para que su consumidor apague el aviso de salud. La bandeja
  /// (botActivity) no lo pide: no pinta salud del SSE.
  Stream<MonitorEvent> _connect(String path, {bool live = false}) async* {
    final cancel = CancelToken();
    try {
      final res = await _dio.get<ResponseBody>(
        path,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          // SSE long-lived: el receiveTimeout lo mataría entre eventos; el
          // heartbeat del backend mantiene viva la conexión.
          receiveTimeout: Duration.zero,
          headers: <String, String>{'Accept': 'text/event-stream'},
        ),
      );
      final body = res.data;
      if (body == null) return;
      if (live) yield _connectedSentinel();
      await for (final ev in decodeSseEvents(body.stream)) {
        if (ev.event.isEmpty) continue; // pings/comentarios sin topic
        final parsed = _tryParse(ev.event, ev.data);
        if (parsed != null) yield parsed;
      }
    } finally {
      cancel.cancel();
    }
  }

  MonitorEvent? _tryParse(String topic, String data) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) return null;
      return MonitorEvent.fromFrame(topic, json);
    } on FormatException {
      return null;
    }
  }
}
