import 'dart:convert';

/// Desenlace tipado de una delegación a un subagente (`spawn_agent`), tal como
/// el motor lo persiste en el resultado del turno role=tool. status ∈
/// {completed, failed, blocked}. En `completed`, `summary` es la línea de
/// desenlace y `result` el detalle (puede ser un blob largo); en `failed`/
/// `blocked`, `reason` describe el motivo.
///
/// El backend marca summary/result/reason con omitempty: un campo vacío NO
/// viaja como cadena vacía sino que su clave desaparece del JSON. El parser lo
/// tolera (clave ausente ⇒ cadena vacía). Como el `content` del turno llega ya
/// pelado, el parseo hace un único `jsonDecode`.
class SubagentOutcomeEnvelope {
  const SubagentOutcomeEnvelope({
    required this.status,
    required this.summary,
    required this.result,
    required this.reason,
  });

  final String status;
  final String summary;
  final String result;
  final String reason;

  bool get isCompleted => status == 'completed';

  static const Set<String> _validStatuses = <String>{
    'completed',
    'failed',
    'blocked',
  };

  /// Intenta interpretar el `content` de un turno role=tool de spawn_agent como
  /// este desenlace. Devuelve null si no es JSON-objeto, si el `status` no es
  /// uno de los conocidos, o si un campo viene mal tipado, para que el render
  /// degrade al volcado monoespaciado.
  static SubagentOutcomeEnvelope? tryParse(String content) {
    if (content.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final status = decoded['status'];
    if (status is! String || !_validStatuses.contains(status)) return null;
    try {
      return SubagentOutcomeEnvelope(
        status: status,
        summary: decoded['summary'] as String? ?? '',
        result: decoded['result'] as String? ?? '',
        reason: decoded['reason'] as String? ?? '',
      );
    } on TypeError {
      return null;
    }
  }
}
