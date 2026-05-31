import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../data/cache/media_thumbnail_loader.dart';
import '../../domain/entities/media_asset.dart';

/// Miniatura cuadrada de un asset en el grid de la galería.
///
/// LINCHPIN: pinta los bytes que resuelve el [MediaThumbnailLoader] (cache local
/// por `ref` o descarga de la `previewUrl` efímera); un consumidor que use
/// [onTap] como picker recibe el asset entero y debe leer `asset.ref` (BARE),
/// NUNCA la previewUrl. Esta clase no decide eso: sólo pinta y delega el tap.
///
/// El loader desacopla el render del origen de los bytes: con cache, la
/// miniatura no se re-descarga al re-entrar a la galería ni depende de que la
/// firma siga viva. Robustez: si el loader devuelve null (sin cache y sin
/// preview, o la descarga falló) o los bytes no decodifican, cae a un
/// placeholder con un ícono según el `contentType` — nunca un crash.
class MediaThumbnail extends StatefulWidget {
  const MediaThumbnail({
    super.key,
    required this.asset,
    required this.loader,
    this.onTap,
  });

  final MediaAsset asset;
  final MediaThumbnailLoader loader;
  final VoidCallback? onTap;

  @override
  State<MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends State<MediaThumbnail> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.loader.load(widget.asset);
  }

  @override
  void didUpdateWidget(MediaThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El grid recicla widgets: si el ref cambia, re-resolver. (Los bytes de un
    // mismo ref son inmutables, así que sólo el cambio de ref importa.)
    if (oldWidget.asset.ref != widget.asset.ref ||
        oldWidget.loader != widget.loader) {
      _bytes = widget.loader.load(widget.asset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTokens.radiusChip);

    return Material(
      color: AppTokens.surface2,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: FutureBuilder<Uint8List?>(
            future: _bytes,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _loading();
              }
              final bytes = snapshot.data;
              if (bytes == null) return _placeholder();
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                // Bytes corruptos (o no-imagen, p. ej. un PDF): mismo placeholder
                // en vez del ícono roto de Flutter.
                errorBuilder: (_, _, _) => _placeholder(),
              );
            },
          ),
        ),
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

  /// Placeholder cuando no hay bytes que pintar: un ícono según el tipo de
  /// contenido sobre la superficie de la card. Para documentos añade el filename
  /// bajo el ícono (un PDF/Office no tiene miniatura, así que el nombre es la
  /// única identidad visual útil); para imagen/video/audio el ícono basta
  /// (las miniaturas reales de video/audio quedan diferidas).
  Widget _placeholder() {
    final asset = widget.asset;
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
