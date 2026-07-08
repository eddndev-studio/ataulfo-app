import 'package:url_launcher/url_launcher.dart';

import '../../domain/repositories/web_link_launcher.dart';

/// Adaptador del puerto [WebLinkLauncher] sobre `url_launcher`. Wrapper
/// delgado: abre la página del sitio en el navegador externo. La llamada
/// nativa NO se unit-testea (necesita el plugin; se valida en smoke device);
/// el único mapeo es parsear la URL y elegir el modo externo.
class UrlLauncherWebLinkLauncher implements WebLinkLauncher {
  const UrlLauncherWebLinkLauncher();

  @override
  Future<void> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // externalApplication: el plan se gestiona en el navegador del sistema,
    // nunca en un webview embebido dentro de la app.
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
