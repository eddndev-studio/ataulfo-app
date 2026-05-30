import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/network/sse/sse_parser.dart';
import '../../domain/entities/message.dart';
import '../dto/message_dto.dart';
import '../mappers/messages_mapper.dart';

/// Puerto de realtime del hilo (S15): el stream SSE `GET /events/stream` del
/// backend, ya filtrado y mapeado a `Message`. Sólo entrega los frames de
/// mensaje (`message.inbound` + `message.outbound`); el resto del fan-out
/// (bot.session, flow.*, ai.*, message.status, label.*) se ignora aquí.
abstract interface class MessagesEventsDatasource {
  /// Mensajes en vivo del bot. El backend scopea por `?botId=`; el filtrado
  /// por conversación (chatLid) lo hace el consumidor (el hilo abierto).
  ///
  /// Best-effort: al cancelar la suscripción se cierra la conexión; un error
  /// de transporte cierra el stream (sin reconexión automática en v1 — la
  /// verdad autoritativa vive en el `GET .../messages` por HTTP, y el
  /// pull-to-refresh recupera). Un frame malformado se omite sin derribar el
  /// stream.
  Stream<Message> threadEvents(String botId);
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
  Stream<Message> threadEvents(String botId) async* {
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
