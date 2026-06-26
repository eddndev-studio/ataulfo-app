import '../entities/label.dart';

/// Puerto de dominio de los Labels internos puestos a UN chat (S10): las
/// etiquetas org-scoped aplicadas a una conversación (por operador, flujos o el
/// agente IA). Distinto del catálogo org-scoped (`LabelsRepository`) y del
/// estado por-chat de WhatsApp.
abstract interface class ChatLabelsRepository {
  /// Labels internos aplicados a este chat. Lista vacía es válida.
  Future<List<Label>> listForChat(String botId, String chatLid);

  /// Asocia un label al chat (idempotente). Habilita la toma del chat: aplicar
  /// una etiqueta de silencio para pausar al bot en esa conversación.
  Future<void> addToChat(String botId, String chatLid, String labelId);

  /// Quita la asociación (idempotente): reanuda al bot al retirar el silencio.
  Future<void> removeFromChat(String botId, String chatLid, String labelId);
}
