/// Puerto consumer-defined para abrir un asset en el visor del sistema
/// (navegador / reproductor nativo). Es la previsualización de multimedia no
/// renderizable inline (video, audio, documentos): el detalle pinta imágenes,
/// pero delega el resto al sistema, que ya sabe reproducir/abrir cada tipo y es
/// cross-platform (móvil, desktop, web) sin embeber un player frágil.
///
/// Recibe la URL firmada EFÍMERA de preview (no el ref BARE): es uso de
/// DISPLAY, jamás identidad. La implementación concreta (sobre `url_launcher`)
/// vive en `data/`.
abstract interface class MediaPreviewLauncher {
  /// Abre [url] en el visor del sistema. Devuelve `true` si pudo lanzarlo.
  Future<bool> open(String url);
}
