import '../../domain/entities/preview_item.dart';

/// DTO de un item del transcript del preview. kind/at canónicos; el resto
/// es opcional por contrato (text en burbujas, tool/summary en acciones).
class PreviewItemDto {
  const PreviewItemDto({
    required this.kind,
    required this.at,
    this.text = '',
    this.tool = '',
    this.summary = '',
    this.mediaRef = '',
    this.stepType = '',
  });

  factory PreviewItemDto.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    final at = json['at'];
    if (kind is! String || at is! String) {
      throw const FormatException('preview item: shape inválido');
    }
    return PreviewItemDto(
      kind: kind,
      text: json['text'] is String ? json['text'] as String : '',
      tool: json['tool'] is String ? json['tool'] as String : '',
      summary: json['summary'] is String ? json['summary'] as String : '',
      mediaRef: json['mediaRef'] is String ? json['mediaRef'] as String : '',
      stepType: json['stepType'] is String ? json['stepType'] as String : '',
      at: DateTime.parse(at).toUtc(),
    );
  }

  final String kind;
  final String text;
  final String tool;
  final String summary;
  final String mediaRef;
  final String stepType;
  final DateTime at;

  PreviewItem toEntity() => PreviewItem(
    kind: kind,
    text: text,
    tool: tool,
    summary: summary,
    mediaRef: mediaRef,
    stepType: stepType,
    at: at,
  );

  static List<PreviewItem> listFromJson(List<dynamic> items) => items
      .map((e) => PreviewItemDto.fromJson(e as Map<String, dynamic>).toEntity())
      .toList(growable: false);
}
