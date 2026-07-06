import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../domain/repositories/device_gallery_port.dart';
import '../../domain/repositories/media_file_picker.dart';

/// Adaptador del puerto [DeviceGalleryPort] sobre el plugin `photo_manager`
/// (headless: sólo da acceso a los assets del carrete; la grilla es propia).
///
/// `availability()` pide el permiso de fotos en runtime
/// (`requestPermissionExtend`): acceso total o limitado ⇒ `available`;
/// permiso denegado ⇒ `denied` (la UI muestra el destino bloqueado con la
/// vía a Ajustes, no lo esconde). Cualquier fallo del plugin degrada a
/// `unsupported`/vacío/null, jamás lanza hacia la UI.
///
/// Las llamadas nativas NO se unit-testean (exigen canales de plataforma; se
/// validan en smoke device); los MAPEOS sí — extraídos a
/// [deviceAssetFromEntity] y [availabilityFromPermission].
class PhotoManagerDeviceGallery implements DeviceGalleryPort {
  const PhotoManagerDeviceGallery();

  @override
  Future<DeviceGalleryAvailability> availability() async {
    try {
      final state = await PhotoManager.requestPermissionExtend();
      return availabilityFromPermission(state);
    } catch (_) {
      return DeviceGalleryAvailability.unsupported;
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await PhotoManager.openSetting();
    } catch (_) {
      // Best-effort: sin ajustes accesibles no hay nada que degradar.
    }
  }

  @override
  Future<List<DeviceMediaAsset>> recentMedia({
    int limit = 60,
    int page = 0,
  }) async {
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
        page: page,
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

/// Mapea el estado de permiso del plugin a la disponibilidad del puerto:
/// con acceso (total o limitado) el carrete está disponible; cualquier otro
/// estado tras PEDIR el permiso significa que el usuario lo negó (o el
/// sistema lo restringe), y la vía de rescate son los Ajustes.
@visibleForTesting
DeviceGalleryAvailability availabilityFromPermission(PermissionState state) =>
    state.hasAccess
    ? DeviceGalleryAvailability.available
    : DeviceGalleryAvailability.denied;

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
