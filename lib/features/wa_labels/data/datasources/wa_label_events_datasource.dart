import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/network/sse/reconnecting_stream.dart';
import '../../../../core/network/sse/sse_parser.dart';
import '../../domain/entities/wa_label_live_event.dart';
import '../dto/wa_label_event_dto.dart';
import '../mappers/wa_labels_mapper.dart';

/// Puerto de realtime del espejo de etiquetas WhatsApp (S21): el stream SSE
/// `GET /events/stream?botId=` (el mismo bus que mensajes), ya filtrado a la
/// familia `label.wa.*` y mapeado a eventos de dominio `WaLabelLiveEvent`.
///
/// Perdurable: si la conexión cae se reconecta con backoff hasta que el
/// consumidor cancela. Un frame malformado o con drift de contrato se omite sin
/// derribar el stream (la verdad autoritativa está en HTTP). `WaLabelReconnected`
/// se emite al reestablecerse: el stream no reproduce el tramo del corte, así
/// que es la señal para reconciliar contra el `GET .../wa-labels`.
abstract interface class WaLabelEventsDatasource {
  Stream<WaLabelLiveEvent> liveEvents(String botId);
}

class DioWaLabelEventsDatasource implements WaLabelEventsDatasource {
  DioWaLabelEventsDatasource(this._dio);

  final Dio _dio;

  /// Topics de la familia `label.wa.*` que pinta esta sección. Cualquier otro
  /// frame del fan-out (mensajes, label.* interno, flow.*, ai.*) se ignora.
  static const Set<String> _topics = <String>{
    'label.wa.edited',
    'label.wa.removed',
    'label.wa.chat',
    'label.wa.message',
  };

  @override
  Stream<WaLabelLiveEvent> liveEvents(String botId) =>
      reconnectingStream<WaLabelLiveEvent>(
        () => connectOnce(botId),
        reconnectMarker: WaLabelReconnected.new,
      );

  /// Una sola conexión SSE: abre el stream, filtra los topics `label.wa.*`,
  /// parsea/mapea los frames a eventos de dominio y termina cuando el backend
  /// cierra o falla. `liveEvents` la envuelve con reconexión; aislarla mantiene
  /// el parseo/scope determinista y testeable sin el loop de reconexión.
  Stream<WaLabelLiveEvent> connectOnce(String botId) async* {
    final cancel = CancelToken();
    try {
      final res = await _dio.get<ResponseBody>(
        '/events/stream',
        queryParameters: <String, dynamic>{'botId': botId},
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          // SSE es long-lived: el receiveTimeout mataría la conexión en cada
          // pausa entre eventos. El heartbeat del backend la mantiene viva.
          receiveTimeout: Duration.zero,
          headers: <String, String>{'Accept': 'text/event-stream'},
        ),
      );

      final body = res.data;
      if (body == null) {
        return;
      }
      await for (final ev in decodeSseEvents(body.stream)) {
        if (_topics.contains(ev.event)) {
          final live = _tryParse(ev.data);
          if (live != null) {
            yield live;
          }
        }
      }
    } finally {
      cancel.cancel();
    }
  }

  /// Traduce el `data` de un frame `label.wa.*` a un evento de dominio. JSON
  /// roto, campos faltantes (FormatException) o un kind desconocido
  /// (ArgumentError, drift de contrato) devuelven null y se omiten: la verdad
  /// autoritativa está en HTTP, así que un frame malo no debe derribar el
  /// realtime.
  WaLabelLiveEvent? _tryParse(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return WaLabelsMapper.eventToLive(WaLabelEventResp.fromJson(json));
    } catch (_) {
      return null;
    }
  }
}
