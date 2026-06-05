import 'package:url_launcher/url_launcher.dart';

import '../../domain/repositories/media_preview_launcher.dart';

/// Adaptador del puerto [MediaPreviewLauncher] sobre `url_launcher`. Wrapper
/// delgado: abre la URL firmada en una app externa (navegador / reproductor del
/// sistema). La llamada nativa NO se unit-testea (necesita el plugin; se valida
/// en smoke device); el único mapeo es parsear la URL y elegir el modo externo.
class UrlLauncherMediaPreviewLauncher implements MediaPreviewLauncher {
  const UrlLauncherMediaPreviewLauncher();

  @override
  Future<bool> open(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return Future<bool>.value(false);
    // externalApplication: deja que el SO elija el visor/reproductor del tipo
    // (un video se abre en el reproductor, un PDF en el visor de documentos).
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
