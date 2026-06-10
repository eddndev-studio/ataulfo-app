import '../../domain/entities/workspace_doc.dart';

/// DTO del workspace (wire camelCase, como flows). `content` es tolerante:
/// el listado lo omite por contrato; los canónicos (name/version/updatedAt)
/// fallan loud.
class WorkspaceDocDto {
  const WorkspaceDocDto({
    required this.name,
    required this.content,
    required this.sizeBytes,
    required this.updatedByKind,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkspaceDocDto.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final version = json['version'];
    final updatedAt = json['updatedAt'];
    if (name is! String || version is! int || updatedAt is! String) {
      throw const FormatException('workspace doc: shape canónico inválido');
    }
    final createdAt = json['createdAt'];
    return WorkspaceDocDto(
      name: name,
      content: json['content'] is String ? json['content'] as String : '',
      sizeBytes: json['sizeBytes'] is int ? json['sizeBytes'] as int : 0,
      updatedByKind: json['updatedByKind'] is String
          ? json['updatedByKind'] as String
          : '',
      version: version,
      createdAt: createdAt is String
          ? DateTime.parse(createdAt).toUtc()
          : DateTime.parse(updatedAt).toUtc(),
      updatedAt: DateTime.parse(updatedAt).toUtc(),
    );
  }

  final String name;
  final String content;
  final int sizeBytes;
  final String updatedByKind;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkspaceDoc toEntity() => WorkspaceDoc(
    name: name,
    content: content,
    sizeBytes: sizeBytes,
    updatedByKind: updatedByKind,
    version: version,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
