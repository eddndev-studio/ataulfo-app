/// DTO del catálogo `GET /bots/{botId}/wa-labels` (ver `waLabelResp` en
/// `ataulfo-go/internal/adapters/httpwalabel/dto.go`).
///
/// `color` es el índice de paleta crudo de WhatsApp (entero; 0 es válido, sin
/// hex). `deleted` viaja siempre (tombstone explícito). El wire es camelCase
/// (a diferencia de otros adaptadores snake_case del repo).
class WaLabelResp {
  const WaLabelResp({
    required this.waLabelId,
    required this.name,
    required this.color,
    required this.deleted,
  });

  factory WaLabelResp.fromJson(Map<String, dynamic> json) {
    final waLabelId = json['waLabelId'];
    final name = json['name'];
    final color = json['color'];
    final deleted = json['deleted'];
    if (waLabelId is! String ||
        name is! String ||
        color is! int ||
        deleted is! bool) {
      throw const FormatException(
        'waLabelResp con campos requeridos faltantes o de tipo incorrecto',
      );
    }
    return WaLabelResp(
      waLabelId: waLabelId,
      name: name,
      color: color,
      deleted: deleted,
    );
  }

  final String waLabelId;
  final String name;
  final int color;
  final bool deleted;
}

/// Wrapper del listado `{items: [...]}` del catálogo. Mismo shape externo que
/// el resto de los list endpoints del repo.
class WaCatalogResp {
  const WaCatalogResp({required this.items});

  factory WaCatalogResp.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('catalogResp sin items array');
    }
    return WaCatalogResp(
      items: items
          .cast<Map<String, dynamic>>()
          .map(WaLabelResp.fromJson)
          .toList(growable: false),
    );
  }

  final List<WaLabelResp> items;
}
