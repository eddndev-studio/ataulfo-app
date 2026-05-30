import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/network/sse/reconnecting_stream.dart';
import '../../../../core/network/sse/sse_parser.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/thread_live_event.dart';
import '../dto/message_dto.dart';
import '../mappers/messages_mapper.dart';

/// Puerto de realtime del hilo (S15): el stream SSE `GET /events/stream` del
/// backend, ya filtrado y mapeado a `Message`. Sólo entrega los frames de
/// mensaje (`message.inbound` + `message.outbound`); el resto del fan-out
/// (bot.session, flow.*, ai.*, message.status, label.*) se ignora aquí.
abstract interface class MessagesEventsDatasource {
  /// Eventos en vivo del bot. El backend scopea por `?botId=`; el filtrado por
  /// conversación (chatLid) lo hace el consumidor (el hilo abierto).
  ///
  /// Perdurable: si la conexión cae (error de transporte o cierre del proxy) se
  /// reconecta sola con backoff hasta que el consumidor cancela la suscripción.
  /// Un frame malformado se omite sin derribar el stream. Emite `LiveMessage`
  /// por cada mensaje y `LiveReconnected` al reestablecerse la conexión: el
  /// stream SSE no reproduce el tramo del corte, así que la reconexión es la
  /// señal para reconciliar contra el `GET .../messages` por HTTP.
  Stream<ThreadLiveEvent> threadEvents(String botId);
}

class DioMessagesEventsDatasource implements MessagesEventsDatasource {
  DioMessagesEventsDatasource(this._dio);

  final Dio _dio;

  /// Topics del bus que pintan una burbuja en el hilo. `message.inbound` trae
  /// los entrantes del contacto (y el envío manual del operador, que el
  /// backend publica ahí con Direction=OUTBOUND); `message.outbound` trae las
  /// auto-respuestas del bot (flujo/IA). El cliente los trata igual y dedupa
  /// por externalId.
  static const Set<String> _messageTopics = <String>{
    'message.inbound',
    'message.outbound',
  };

  @override
  Stream<ThreadLiveEvent> threadEvents(String botId) =>
      reconnectingStream<ThreadLiveEvent>(
        () => connectOnce(botId).map(LiveMessage.new),
        reconnectMarker: LiveReconnected.new,
      );

  /// Una sola conexión SSE: abre el stream, parsea/filtra/mapea los frames de
  /// mensaje y termina cuando el backend cierra o falla. `threadEvents` la
  /// envuelve con reconexión; aislarla mantiene esta lógica (parseo/scope)
  /// determinista y testeable sin el loop de reconexión.
  Stream<Message> connectOnce(String botId) async* {
    // CancelToken para cerrar la conexión SSE al cancelar la suscripción del
    // stream (el `finally` corre cuando el generador se cancela).
    final cancel = CancelToken();
    try {
      final res = await _dio.get<ResponseBody>(
        '/events/stream',
        queryParameters: <String, dynamic>{'botId': botId},
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          // SSE es long-lived: el receiveTimeout (que mide el hueco entre
          // datos) lo mataría en cada pausa entre eventos. El heartbeat del
          // backend mantiene viva la conexión; aquí desactivamos el timeout.
          receiveTimeout: Duration.zero,
          headers: <String, String>{'Accept': 'text/event-stream'},
        ),
      );

      final body = res.data;
      if (body == null) {
        return;
      }
      await for (final ev in decodeSseEvents(body.stream)) {
        if (!_messageTopics.contains(ev.event)) {
          continue;
        }
        final msg = _tryParse(ev.data);
        if (msg != null) {
          yield msg;
        }
      }
    } finally {
      cancel.cancel();
    }
  }

  /// Traduce el `data` de un frame de mensaje a `Message`. Un frame con JSON
  /// roto o un enum desconocido (drift de contrato) devuelve null y se omite:
  /// la verdad autoritativa está en HTTP, así que un frame malo no debe
  /// derribar el realtime.
  Message? _tryParse(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return MessagesMapper.respToMessage(MessageResp.fromJson(json));
    } catch (_) {
      return null;
    }
  }
}
