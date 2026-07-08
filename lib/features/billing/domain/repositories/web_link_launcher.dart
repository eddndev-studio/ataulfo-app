/// Puerto consumer-defined para abrir una página del sitio web del producto
/// en el navegador del sistema. La app muestra el plan SOLO-LECTURA:
/// contratar, mejorar o gestionar el plan vive en la web, y este puerto es
/// el único puente hacia allá. La implementación concreta (sobre
/// `url_launcher`) vive en `data/`; los tests inyectan un fake y asserten
/// la URL exacta.
abstract interface class WebLinkLauncher {
  /// Abre [url] en el navegador externo. Best-effort: la pantalla no
  /// bloquea ni reporta si el SO no puede abrirla.
  Future<void> open(String url);
}
