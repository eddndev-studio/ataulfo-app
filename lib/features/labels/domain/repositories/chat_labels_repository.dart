import '../entities/label.dart';

/// Puerto de dominio de SOLO LECTURA de los Labels internos puestos a UN chat
/// (S10): las etiquetas org-scoped aplicadas a una conversación (por operador,
/// flujos o el agente IA). Distinto del catálogo org-scoped (`LabelsRepository`)
/// y del estado por-chat de WhatsApp.
abstract interface class ChatLabelsRepository {
  /// Labels internos aplicados a este chat. Lista vacía es válida.
  Future<List<Label>> listForChat(String botId, String chatLid);
}
