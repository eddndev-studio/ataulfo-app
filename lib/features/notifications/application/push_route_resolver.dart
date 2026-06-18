/// Traduce el `data` de un push (claves `eventType`/`botId` y, cuando el
/// candidato lo porta, `chatLID` del dispatcher del backend) a la ruta de la
/// app que el tap debe abrir.
///
/// Total a propósito: SIEMPRE devuelve un destino útil. Un payload incompleto
/// o un evento que este cliente no conoce caen a la bandeja de notificaciones
/// (donde el item de inbox correspondiente da el contexto), nunca a "no pasa
/// nada" — que era exactamente el bug.
///
/// Con `chatLID` en el push, el tap hace deep-link de UN toque al destino real:
/// el hilo (mensaje entrante / alerta del agente) o las ejecuciones del chat
/// (flujo fallido). Sin `chatLID` (push agregado o legacy) cae al mejor destino
/// alcanzable sólo con el bot.
String pushRouteFor(Map<String, Object?> data) {
  final botId = data['botId'];
  if (botId is! String || botId.isEmpty) {
    return '/notifications';
  }
  final id = Uri.encodeComponent(botId);
  final rawChat = data['chatLID'];
  final chat = (rawChat is String && rawChat.isNotEmpty)
      ? Uri.encodeComponent(rawChat)
      : null;
  return switch (data['eventType']) {
    'message.inbound.new' =>
      chat != null ? '/bots/$id/sessions/$chat' : '/bots/$id/sessions',
    'agent.alert' =>
      chat != null ? '/bots/$id/sessions/$chat' : '/notifications',
    'bot.disconnected' => '/bots/$id/connect',
    'flow.failed' =>
      chat != null ? '/bots/$id/sessions/$chat/executions' : '/bots/$id',
    _ => '/notifications',
  };
}
