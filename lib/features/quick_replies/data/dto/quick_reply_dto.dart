import '../../domain/entities/quick_reply.dart';

/// DTO del catálogo `GET /bots/{botId}/quick-replies` (ver `quickReplyResp` en
/// `ataulfo-go/internal/adapters/httpquickreply/dto.go`). El wire es camelCase.
///
/// `waQuickReplyId` es el id opaco (Index[1]), no el shortcut. `deleted` viaja
/// siempre (tombstone explícito). El espejo del backend también envía
/// keywords/count/associatedLabelIds; este cliente NO los modela (el selector ⚡
/// solo necesita atajo + mensaje), así que `fromJson` los ignora.
class QuickReplyResp {
  const QuickReplyResp({
    required this.waQuickReplyId,
    required this.shortcut,
    required this.message,
    required this.deleted,
  });

  factory QuickReplyResp.fromJson(Map<String, dynamic> json) {
    final waQuickReplyId = json['waQuickReplyId'];
    final shortcut = json['shortcut'];
    final message = json['message'];
    final deleted = json['deleted'];
    if (waQuickReplyId is! String ||
        shortcut is! String ||
        message is! String ||
        deleted is! bool) {
      throw const FormatException(
        'quickReplyResp con campos requeridos faltantes o de tipo incorrecto',
      );
    }
    return QuickReplyResp(
      waQuickReplyId: waQuickReplyId,
      shortcut: shortcut,
      message: message,
      deleted: deleted,
    );
  }

  final String waQuickReplyId;
  final String shortcut;
  final String message;
  final bool deleted;

  QuickReply toEntity() => QuickReply(
    waQuickReplyId: waQuickReplyId,
    shortcut: shortcut,
    message: message,
    deleted: deleted,
  );
}

/// Wrapper del listado `{items: [...]}` del catálogo. Mismo shape externo que el
/// resto de los list endpoints del repo.
class QuickRepliesCatalogResp {
  const QuickRepliesCatalogResp({required this.items});

  factory QuickRepliesCatalogResp.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('catalogResp sin items array');
    }
    return QuickRepliesCatalogResp(
      items: items
          .cast<Map<String, dynamic>>()
          .map(QuickReplyResp.fromJson)
          .toList(growable: false),
    );
  }

  final List<QuickReplyResp> items;

  List<QuickReply> toEntities() =>
      items.map((r) => r.toEntity()).toList(growable: false);
}
