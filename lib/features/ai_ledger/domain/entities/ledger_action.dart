/// Una acción con efecto del bot ya resuelta a texto de negocio (la bitácora,
/// S30). Distinta del ai-log crudo: no trae prompts ni razonamiento, sólo QUÉ
/// hizo el bot. `action` es la frase ("Aplicó una etiqueta"); `detail` el dato
/// concreto cuando lo hay (nombre de la etiqueta, id del flujo, archivo…).
class LedgerAction {
  const LedgerAction({
    required this.id,
    required this.runId,
    required this.toolName,
    required this.action,
    required this.detail,
    required this.createdAt,
  });

  final int id;
  final String runId;
  final String toolName;
  final String action;
  final String detail;
  final DateTime createdAt;
}
