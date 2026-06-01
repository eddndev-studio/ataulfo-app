/// DTO plano del frame SSE de la familia `label.wa.*` (ver `waLabelWire` en
/// `ataulfo-go/internal/adapters/httpevents/dto.go`). El `kind` discrimina qué
/// campos aplican; el mapeo a la jerarquía sellada `WaLabelLiveEvent` ocurre en
/// `WaLabelsMapper.eventToLive`.
///
/// `color` y `labeled` viajan SIEMPRE (no omitempty: 0 es un índice válido y
/// false es la señal de desasociación). `name`/`chatLid`/`messageId` son
/// omitempty — solo en los kinds que aplican — y se materializan como `null`.
/// `at` (timestamp del evento) no se modela: el catálogo aplica last-write-wins
/// por upsert, sin necesitar ordenarlo.
class WaLabelEventResp {
  const WaLabelEventResp({
    required this.botId,
    required this.kind,
    required this.waLabelId,
    required this.name,
    required this.color,
    required this.chatLid,
    required this.messageId,
    required this.labeled,
  });

  factory WaLabelEventResp.fromJson(Map<String, dynamic> json) {
    final botId = json['botId'];
    final kind = json['kind'];
    final waLabelId = json['waLabelId'];
    final color = json['color'];
    final labeled = json['labeled'];
    if (botId is! String ||
        kind is! String ||
        waLabelId is! String ||
        color is! int ||
        labeled is! bool) {
      throw const FormatException(
        'waLabelEvent con campos requeridos faltantes o de tipo incorrecto',
      );
    }
    final rawName = json['name'];
    final rawChatLid = json['chatLid'];
    final rawMessageId = json['messageId'];
    return WaLabelEventResp(
      botId: botId,
      kind: kind,
      waLabelId: waLabelId,
      color: color,
      labeled: labeled,
      name: rawName is String ? rawName : null,
      chatLid: rawChatLid is String ? rawChatLid : null,
      messageId: rawMessageId is String ? rawMessageId : null,
    );
  }

  final String botId;
  final String kind;
  final String waLabelId;
  final String? name;
  final int color;
  final String? chatLid;
  final String? messageId;
  final bool labeled;
}
