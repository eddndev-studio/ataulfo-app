/// DTOs de las asociaciones espejadas: etiqueta↔chat y etiqueta↔mensaje
/// (`chatAssocResp`/`msgAssocResp` en httpwalabel/dto.go). `labeled` viaja
/// siempre (false = desasociación conservada en el espejo).

class WaChatAssocResp {
  const WaChatAssocResp({
    required this.chatLid,
    required this.waLabelId,
    required this.labeled,
  });

  factory WaChatAssocResp.fromJson(Map<String, dynamic> json) {
    final chatLid = json['chatLid'];
    final waLabelId = json['waLabelId'];
    final labeled = json['labeled'];
    if (chatLid is! String || waLabelId is! String || labeled is! bool) {
      throw const FormatException(
        'chatAssocResp con campos requeridos faltantes o de tipo incorrecto',
      );
    }
    return WaChatAssocResp(
      chatLid: chatLid,
      waLabelId: waLabelId,
      labeled: labeled,
    );
  }

  final String chatLid;
  final String waLabelId;
  final bool labeled;
}

class WaChatAssocListResp {
  const WaChatAssocListResp({required this.items});

  factory WaChatAssocListResp.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('chatAssocListResp sin items array');
    }
    return WaChatAssocListResp(
      items: items
          .cast<Map<String, dynamic>>()
          .map(WaChatAssocResp.fromJson)
          .toList(growable: false),
    );
  }

  final List<WaChatAssocResp> items;
}

class WaMsgAssocResp {
  const WaMsgAssocResp({
    required this.chatLid,
    required this.messageId,
    required this.waLabelId,
    required this.labeled,
  });

  factory WaMsgAssocResp.fromJson(Map<String, dynamic> json) {
    final chatLid = json['chatLid'];
    final messageId = json['messageId'];
    final waLabelId = json['waLabelId'];
    final labeled = json['labeled'];
    if (chatLid is! String ||
        messageId is! String ||
        waLabelId is! String ||
        labeled is! bool) {
      throw const FormatException(
        'msgAssocResp con campos requeridos faltantes o de tipo incorrecto',
      );
    }
    return WaMsgAssocResp(
      chatLid: chatLid,
      messageId: messageId,
      waLabelId: waLabelId,
      labeled: labeled,
    );
  }

  final String chatLid;
  final String messageId;
  final String waLabelId;
  final bool labeled;
}

class WaMsgAssocListResp {
  const WaMsgAssocListResp({required this.items});

  factory WaMsgAssocListResp.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('msgAssocListResp sin items array');
    }
    return WaMsgAssocListResp(
      items: items
          .cast<Map<String, dynamic>>()
          .map(WaMsgAssocResp.fromJson)
          .toList(growable: false),
    );
  }

  final List<WaMsgAssocResp> items;
}
