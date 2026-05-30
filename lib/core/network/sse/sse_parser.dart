import 'dart:convert';

/// Un frame SSE decodificado: `event` es la línea `event:` (default `message`
/// si el productor la omite) y `data` el payload (líneas `data:` unidas por
/// `\n`, según la spec). Los comentarios (`:`…, p. ej. el heartbeat `: ping`)
/// y los frames sin `data` NO producen `SseEvent`.
class SseEvent {
  const SseEvent({required this.event, required this.data});

  final String event;
  final String data;
}

/// Decodifica un stream de bytes `text/event-stream` a [SseEvent].
///
/// El framing SSE es por líneas: cada `field: value` aporta a un frame y una
/// línea en blanco lo cierra. Esta implementación es robusta al troceado
/// arbitrario del transporte —un chunk puede partir una línea (o un carácter
/// multibyte) por la mitad— porque (1) `utf8.decoder` reensambla secuencias
/// multibyte partidas y (2) acumulamos en un buffer hasta tener líneas
/// completas (`\n`), conservando el resto parcial entre chunks.
///
/// Sólo se interpretan los campos `event` y `data`; `id`/`retry` se ignoran
/// (no los usamos). El heartbeat (`: ping`) es un comentario y no emite.
Stream<SseEvent> decodeSseEvents(Stream<List<int>> bytes) async* {
  var buffer = '';
  String? eventType;
  final data = <String>[];

  await for (final chunk in utf8.decoder.bind(bytes)) {
    buffer += chunk;
    int nl;
    while ((nl = buffer.indexOf('\n')) != -1) {
      var line = buffer.substring(0, nl);
      buffer = buffer.substring(nl + 1);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1); // tolera CRLF
      }

      if (line.isEmpty) {
        // Fin de frame: despacha sólo si hubo al menos una línea `data`.
        if (data.isNotEmpty) {
          yield SseEvent(event: eventType ?? 'message', data: data.join('\n'));
        }
        eventType = null;
        data.clear();
        continue;
      }
      if (line.startsWith(':')) {
        continue; // comentario (heartbeat): se ignora
      }

      final colon = line.indexOf(':');
      final field = colon == -1 ? line : line.substring(0, colon);
      var value = colon == -1 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) {
        value = value.substring(1); // un único espacio opcional tras los `:`
      }
      switch (field) {
        case 'event':
          eventType = value;
        case 'data':
          data.add(value);
      }
    }
  }
}
