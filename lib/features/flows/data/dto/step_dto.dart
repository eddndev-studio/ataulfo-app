import 'dart:convert';

/// DTO de un Step del listado `GET /flows/{flowId}/steps` (ver
/// `stepResp` en `ataulfo-go/internal/adapters/httpflows/step_dto.go`).
///
/// `type` queda como String en este DTO (no enum) — el mapeo al enum
/// `StepType` ocurre en el mapper, donde un drift del backend (tipo
/// nuevo) propaga `ArgumentError` fail-loud sin envolver.
///
/// `metadata` viaja en el wire como objeto JSON (json.RawMessage del
/// backend). Aquí lo aplastamos a `metadataJson` (string) para
/// transportarlo sin re-parsearlo; el cliente lo interpretará por
/// StepType cuando F7 (CONDITIONAL_TIME) o slices de mutación lo
/// necesiten.
class StepResp {
  const StepResp({
    required this.id,
    required this.flowId,
    required this.type,
    required this.order,
    required this.content,
    required this.mediaRef,
    required this.metadataJson,
    required this.delayMs,
    required this.jitterPct,
    required this.aiOnly,
  });

  factory StepResp.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final flowId = json['flowId'];
    final type = json['type'];
    final order = json['order'];
    final content = json['content'];
    final mediaRef = json['mediaRef'];
    final delayMs = json['delayMs'];
    final jitterPct = json['jitterPct'];
    final aiOnly = json['aiOnly'];
    if (id is! String ||
        flowId is! String ||
        type is! String ||
        order is! int ||
        content is! String ||
        mediaRef is! String ||
        delayMs is! int ||
        jitterPct is! int ||
        aiOnly is! bool) {
      throw const FormatException('stepResp: clave obligatoria ausente');
    }
    // metadata es opcional en el JSON del wire. Cuando viene como Map se
    // re-serializa a string para guardarlo opaco. Vacío/ausente ⇒ "{}".
    final rawMeta = json['metadata'];
    final String metadataJson;
    if (rawMeta == null) {
      metadataJson = '{}';
    } else if (rawMeta is Map) {
      metadataJson = jsonEncode(rawMeta);
    } else if (rawMeta is String) {
      // El backend canónico manda objeto; si llega string, asumimos que
      // ya viene serializado (raro pero defensivo).
      metadataJson = rawMeta;
    } else {
      throw const FormatException(
        'stepResp.metadata no es objeto json ni string',
      );
    }
    return StepResp(
      id: id,
      flowId: flowId,
      type: type,
      order: order,
      content: content,
      mediaRef: mediaRef,
      metadataJson: metadataJson,
      delayMs: delayMs,
      jitterPct: jitterPct,
      aiOnly: aiOnly,
    );
  }

  final String id;
  final String flowId;
  final String type;
  final int order;
  final String content;
  final String mediaRef;
  final String metadataJson;
  final int delayMs;
  final int jitterPct;
  final bool aiOnly;
}

/// Wrapper de la lista `GET /flows/{flowId}/steps` → `{items:[...]}`.
class ListStepsResp {
  const ListStepsResp({required this.items});

  factory ListStepsResp.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List<dynamic>) {
      throw const FormatException('listStepsResp: items ausente o no es lista');
    }
    return ListStepsResp(
      items: items
          .cast<Map<String, dynamic>>()
          .map(StepResp.fromJson)
          .toList(growable: false),
    );
  }

  final List<StepResp> items;
}
