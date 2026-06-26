/// Resuelve las etiquetas de silencio EFECTIVAS de un bot: los ids de label que,
/// presentes en un chat, hacen que el agente IA no responda ahí. Hoy provienen
/// de la plantilla del bot; el puerto aísla a la toma del chat de ese detalle.
abstract interface class SilenceLabelsResolver {
  /// Ids de etiquetas de silencio del bot. Lista vacía = el bot no tiene
  /// silencio configurado (la toma del chat por etiqueta no aplica).
  Future<List<String>> forBot(String botId);
}
