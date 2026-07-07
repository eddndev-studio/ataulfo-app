import '../entities/org_branding.dart';

/// Puerto del módulo de personalización sobre la marca de documentos de la
/// org. Las impls lanzan `OrgBrandingFailure` tipadas.
abstract interface class OrgBrandingRepository {
  /// Estado actual de la marca (siempre responde, haya fila o no).
  Future<OrgBranding> get();

  /// Guarda el logo (ref BARE de la galería, PNG/JPEG de esta org). El
  /// backend upserta la marca ESTRUCTURADA: el nombre de la org viaja solo
  /// (se toma fresco al sembrar cada taller), por eso aquí solo va el ref.
  Future<void> setLogo(String mediaRef);

  /// Borra la marca guardada: los documentos vuelven al estilo estándar con
  /// el nombre de la org.
  Future<void> reset();
}
