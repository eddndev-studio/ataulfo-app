import '../../domain/entities/media_asset.dart';
import '../dto/media_dto.dart';

/// Traduce los DTOs del wire de Media a entidades de dominio. Puro: cualquier
/// llamador (datasource, test, futura cache) lo compone sin estado.
///
/// Invariante portada por el nombre: `resp.ref` (BARE) → `entity.ref`, y
/// `resp.url` (firmada, efímera) → `entity.previewUrl`. NUNCA al revés: el ref
/// es identidad permanente; la previewUrl expira. `created_at` ISO-8601 se
/// parsea a `DateTime` (UTC del wire).
class MediaMapper {
  const MediaMapper._();

  static UploadedMedia uploadRespToEntity(UploadResp resp) =>
      UploadedMedia(ref: resp.ref, previewUrl: resp.url);

  static MediaAsset assetRespToEntity(MediaAssetResp resp) => MediaAsset(
    ref: resp.ref,
    previewUrl: resp.url,
    filename: resp.filename,
    contentType: resp.contentType,
    size: resp.size,
    createdAt: DateTime.parse(resp.createdAt),
  );

  static MediaPage listRespToPage(MediaListResp resp) => MediaPage(
    assets: resp.assets.map(assetRespToEntity).toList(growable: false),
    nextCursor: resp.nextCursor,
  );
}
