/// DTOs del mapeo explícito etiqueta-WhatsApp ↔ Label interno
/// (`mappingResp` en httpwalabel/dto.go). El `labelId` es el uuid de un Label
/// interno (S10); el `waLabelId` es el id de la etiqueta WhatsApp.

class WaMappingResp {
  const WaMappingResp({required this.waLabelId, required this.labelId});

  factory WaMappingResp.fromJson(Map<String, dynamic> json) {
    final waLabelId = json['waLabelId'];
    final labelId = json['labelId'];
    if (waLabelId is! String || labelId is! String) {
      throw const FormatException(
        'mappingResp con campos requeridos faltantes o de tipo incorrecto',
      );
    }
    return WaMappingResp(waLabelId: waLabelId, labelId: labelId);
  }

  final String waLabelId;
  final String labelId;
}

class WaMappingListResp {
  const WaMappingListResp({required this.items});

  factory WaMappingListResp.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('mappingListResp sin items array');
    }
    return WaMappingListResp(
      items: items
          .cast<Map<String, dynamic>>()
          .map(WaMappingResp.fromJson)
          .toList(growable: false),
    );
  }

  final List<WaMappingResp> items;
}
