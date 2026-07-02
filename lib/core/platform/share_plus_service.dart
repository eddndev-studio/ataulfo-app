import 'package:share_plus/share_plus.dart';

import 'share_service.dart';

/// Adaptador del puerto [ShareService] sobre `share_plus`. Wrapper delgado:
/// abre el selector de apps del sistema (`ACTION_SEND` en Android) con el
/// texto dado. La llamada nativa NO se unit-testea (necesita el plugin; se
/// valida en smoke device); el único mapeo es envolver el texto en
/// [ShareParams] y descartar el [ShareResult] (el selector es su propio
/// feedback).
class SharePlusService implements ShareService {
  const SharePlusService();

  @override
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }
}
