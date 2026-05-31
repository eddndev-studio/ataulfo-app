import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/entities/media_asset.dart';

/// Miniatura cuadrada de un asset en el grid de la galería.
///
/// LINCHPIN: muestra [MediaAsset.previewUrl] (URL firmada EFÍMERA) sólo para el
/// render; un consumidor que use [onTap] como picker recibe el asset entero y
/// debe leer `asset.ref` (BARE), NUNCA la previewUrl. Esta clase no decide eso:
/// sólo pinta y delega el tap.
///
/// Robustez: si `previewUrl` es null (omitempty del wire) o la imagen falla al
/// cargar (la firma pudo expirar), cae a un placeholder con un ícono según el
/// `contentType` — nunca un crash ni un `!` sobre null.
class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({super.key, required this.asset, this.onTap});

  final MediaAsset asset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTokens.radiusChip);
    final url = asset.previewUrl;
    final Widget content = url == null
        ? _placeholder()
        : Image.network(
            url,
            fit: BoxFit.cover,
            // La firma pudo expirar o la red caer: el errorBuilder cae al mismo
            // placeholder en vez de mostrar el ícono roto de Flutter.
            errorBuilder: (_, _, _) => _placeholder(),
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : _loading(),
          );

    return Material(
      color: AppTokens.surface2,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(aspectRatio: 1, child: content),
      ),
    );
  }

  Widget _loading() => const Center(
    child: SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(AppTokens.text2),
      ),
    ),
  );

  /// Placeholder cuando no hay preview (o falló): un ícono según el tipo de
  /// contenido sobre la superficie de la card. Para documentos añade el filename
  /// bajo el ícono (un PDF/Office no tiene miniatura, así que el nombre es la
  /// única identidad visual útil); para imagen/video/audio el ícono basta
  /// (las miniaturas reales de video/audio quedan diferidas).
  Widget _placeholder() {
    final name = asset.filename.trim();
    final showName = _isDocument(asset.contentType) && name.isNotEmpty;
    return Container(
      key: Key('media_thumbnail.placeholder.${asset.ref}'),
      color: AppTokens.surface2,
      padding: const EdgeInsets.all(AppTokens.sp2),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(_iconFor(asset.contentType), color: AppTokens.text2, size: 28),
          if (showName) ...<Widget>[
            const SizedBox(height: AppTokens.sp1),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTokens.text2, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  /// Familia "documento": application/* y text/* (PDF, Office, texto/CSV). Es la
  /// única familia cuya miniatura no es renderizable, así que se etiqueta con el
  /// nombre del archivo.
  static bool _isDocument(String contentType) =>
      contentType.startsWith('application/') || contentType.startsWith('text/');

  /// Ícono representativo por familia de `contentType`. Un tipo no catalogado
  /// cae al genérico de archivo.
  static IconData _iconFor(String contentType) {
    if (contentType.startsWith('image/')) return Icons.image_outlined;
    if (contentType.startsWith('video/')) return Icons.movie_outlined;
    if (contentType.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (contentType == 'application/pdf') {
      return Icons.picture_as_pdf_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }
}
