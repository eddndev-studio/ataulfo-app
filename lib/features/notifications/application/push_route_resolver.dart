/// Traduce el `data` de un push (claves `eventType`/`botId` del dispatcher
/// del backend) a la ruta de la app que el tap debe abrir.
///
/// Total a propósito: SIEMPRE devuelve un destino útil. Un payload incompleto
/// o un evento que este cliente no conoce caen a la bandeja de notificaciones
/// (donde el item de inbox correspondiente da el contexto), nunca a "no pasa
/// nada" — que era exactamente el bug.
///
/// Los push de mensajes entrantes se agregan por bot (sin chat puntual en el
/// payload), así que su destino es la lista de chats del bot.
String pushRouteFor(Map<String, Object?> data) {
  final botId = data['botId'];
  if (botId is! String || botId.isEmpty) {
    return '/notifications';
  }
  final id = Uri.encodeComponent(botId);
  return switch (data['eventType']) {
    'message.inbound.new' => '/bots/$id/sessions',
    'bot.disconnected' => '/bots/$id/connect',
    'flow.failed' => '/bots/$id',
    _ => '/notifications',
  };
}
