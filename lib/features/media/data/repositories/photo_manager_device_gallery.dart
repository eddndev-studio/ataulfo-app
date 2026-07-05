import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../domain/repositories/device_gallery_port.dart';
import '../../domain/repositories/media_file_picker.dart';

/// Adaptador del puerto [DeviceGalleryPort] sobre el plugin `photo_manager`
/// (headless: sólo da acceso a los assets del carrete; la grilla es propia).
///
/// `isSupported()` pide el permiso de fotos en runtime
/// (`requestPermissionExtend`): con acceso total o limitado responde true;
/// denegado responde false y la UI simplemente no ofrece el destino — nunca
/// un estado de error dentro del sheet. Cualquier fallo del plugin degrada a
/// false/vacío/null, jamás lanza hacia la UI.
///
/// Las llamadas nativas NO se unit-testean (exigen canales de plataforma; se
/// validan en smoke device); el MAPEO del asset sí — extraído a
/// [deviceAssetFromEntity].
class PhotoManagerDeviceGallery implements DeviceGalleryPort {
  const PhotoManagerDeviceGallery();

  @override
  Future<bool> isSupported() async {
    try {
      final state = await PhotoManager.requestPermissionExtend();
      return state.hasAccess;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<DeviceMediaAsset>> recentMedia({int limit = 60}) async {
    try {
      // El álbum virtual "todo" (onlyAll) ordenado por fecha de creación
      // descendente ES el carrete de recientes. `needTitle` materializa el
      // display name en la enumeración: la grilla y el envío necesitan el
      // nombre con extensión real.
      final paths = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.common,
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(needTitle: true),
          videoOption: const FilterOption(needTitle: true),
          orders: const <OrderOption>[
            OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );
      if (paths.isEmpty) return const <DeviceMediaAsset>[];
      final entities = await paths.first.getAssetListPaged(
        page: 0,
        size: limit,
      );
      return entities.map(deviceAssetFromEntity).toList(growable: false);
    } catch (_) {
      return const <DeviceMediaAsset>[];
    }
  }

  @override
  Future<Uint8List?> thumbnailFor(
    DeviceMediaAsset asset, {
    int size = 256,
  }) async {
    try {
      final entity = await AssetEntity.fromId(asset.id);
      return await entity?.thumbnailDataWithSize(ThumbnailSize.square(size));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PickedMedia?> bytesFor(DeviceMediaAsset asset) async {
    try {
      final entity = await AssetEntity.fromId(asset.id);
      final bytes = await entity?.originBytes;
      if (bytes == null) return null;
      return PickedMedia(bytes: bytes, filename: asset.filename);
    } catch (_) {
      return null;
    }
  }
}

/// Mapea un [AssetEntity] del plugin al asset del dominio. Sin título en el
/// MediaStore (display name ausente) cae a un nombre de respaldo `id.ext`
/// cuya extensión conserva la familia (jpg/mp4) para que la inferencia del
/// `type` de envío no degrade a `document`.
@visibleForTesting
DeviceMediaAsset deviceAssetFromEntity(AssetEntity entity) {
  final isVideo = entity.type == AssetType.video;
  final title = entity.title;
  return DeviceMediaAsset(
    id: entity.id,
    filename: (title == null || title.isEmpty)
        ? '${entity.id}.${isVideo ? 'mp4' : 'jpg'}'
        : title,
    isVideo: isVideo,
    durationMs: isVideo ? entity.videoDuration.inMilliseconds : null,
  );
}
