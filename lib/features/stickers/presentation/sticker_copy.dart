import '../domain/failures/sticker_failure.dart';

/// Traduce una falla de sticker a copy es-MX para la UI. Un rechazo 422 ya trae
/// su copy del datasource; si no lo trae (código no mapeado) cae al genérico.
String stickerFailureCopy(StickerFailure f) => switch (f) {
  StickerRejectedFailure(:final message) =>
    message ?? 'No se pudo generar el sticker. Inténtalo de nuevo.',
  StickerUnavailableFailure() =>
    'La generación de imágenes no está disponible ahora. Inténtalo más tarde.',
  StickerNetworkFailure() =>
    'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
  StickerServerFailure() =>
    'El servidor tuvo un problema. Inténtalo más tarde.',
  StickerUnknownFailure() =>
    'No se pudo generar el sticker. Inténtalo de nuevo.',
};
