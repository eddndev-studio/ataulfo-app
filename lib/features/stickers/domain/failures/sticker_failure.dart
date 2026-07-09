/// Fallas tipadas del dominio de stickers. El datasource traduce el wire; la
/// presentación muestra el copy. Un rechazo 422 ya trae su copy es-MX (el
/// datasource conoce los códigos); el código crudo del wire jamás llega a la UI.
sealed class StickerFailure implements Exception {
  const StickerFailure();
}

/// Red caída / timeout.
class StickerNetworkFailure extends StickerFailure {
  const StickerNetworkFailure();
}

/// 422: el backend rechazó la generación por una causa de negocio (motivo
/// inválido, cuota agotada, prueba/suscripción, plan). [message] ya es copy
/// es-MX; null si el código no estaba mapeado (la UI cae a copy genérico).
class StickerRejectedFailure extends StickerFailure {
  const StickerRejectedFailure(this.message);
  final String? message;
}

/// 503: el dominio de imagen no está disponible (sin proveedor).
class StickerUnavailableFailure extends StickerFailure {
  const StickerUnavailableFailure();
}

/// 5xx genérico.
class StickerServerFailure extends StickerFailure {
  const StickerServerFailure();
}

/// Cualquier otra cosa (wire roto, status inesperado).
class StickerUnknownFailure extends StickerFailure {
  const StickerUnknownFailure();
}
