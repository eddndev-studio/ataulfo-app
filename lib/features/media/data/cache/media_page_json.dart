import '../../domain/entities/media_asset.dart';

/// Serialización de una [MediaPage] a/desde un mapa JSON para el cache en disco.
///
/// Es DELIBERADAMENTE independiente de los DTOs del wire (`media_dto.dart`): el
/// wire es un contrato del servidor que puede evolucionar; el formato en disco
/// es nuestro y lo controlamos. Persistir el entity directamente evita acoplar
/// el cache local a cambios del contrato HTTP.
///
/// La `previewUrl` se persiste aunque sea efímera: al leer una página stale
/// (offline), sus firmas pueden estar vencidas, pero las miniaturas con bytes
/// ya cacheados se pintan igual (el loader ignora la previewUrl en un hit). Las
/// no cacheadas caen a placeholder — degradación, no crash.
Map<String, dynamic> mediaPageToJson(MediaPage page) => <String, dynamic>{
  'nextCursor': page.nextCursor,
  'assets': page.assets.map(_assetToJson).toList(),
};

MediaPage mediaPageFromJson(Map<String, dynamic> json) => MediaPage(
  nextCursor: json['nextCursor'] as String,
  assets: (json['assets'] as List<dynamic>)
      .map((dynamic e) => _assetFromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _assetToJson(MediaAsset a) => <String, dynamic>{
  'ref': a.ref,
  'previewUrl': a.previewUrl,
  'filename': a.filename,
  'contentType': a.contentType,
  'size': a.size,
  // ISO-8601 en UTC: estable y sin ambigüedad de zona al releer.
  'createdAt': a.createdAt.toUtc().toIso8601String(),
};

MediaAsset _assetFromJson(Map<String, dynamic> json) => MediaAsset(
  ref: json['ref'] as String,
  previewUrl: json['previewUrl'] as String?,
  filename: json['filename'] as String,
  contentType: json['contentType'] as String,
  size: json['size'] as int,
  createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
);
