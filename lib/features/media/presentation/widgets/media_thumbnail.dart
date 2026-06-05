import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/repositories/media_thumbnail_loader.dart';

/// Miniatura cuadrada de un asset en el grid de la galería.
///
/// LINCHPIN: pinta los bytes que resuelve el [MediaThumbnailLoader] (cache local
/// por `ref` o descarga de la `previewUrl` efímera). Como picker, el call-site
/// envuelve [onTap] en una closure que captura el asset y debe leer `asset.ref`
/// (BARE), NUNCA la previewUrl. Esta clase no decide eso: sólo pinta y delega el
/// tap ([onTap] es un `VoidCallback`; no transporta el asset por sí mismo).
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
    this.onLongPress,
    this.selected = false,
  });

  final MediaAsset asset;
  final MediaThumbnailLoader loader;
  final VoidCallback? onTap;

  /// Long-press (entra/alterna el modo selección). Null ⇒ sin selección (picker).
  final VoidCallback? onLongPress;

  /// Seleccionado en el modo selección múltiple: tinte + check sobre la celda.
  final bool selected;

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
        onLongPress: widget.onLongPress,
        child: AspectRatio(
          aspectRatio: 1,
          // El visual (imagen/placeholder/spinner) llena la celda; el caption
          // con el displayName flota abajo sobre un scrim para ser legible sea
          // cual sea el contenido. Misma rotulación en todos los tipos: el
          // alias (o filename) identifica el asset sin abrir el detalle.
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              FutureBuilder<Uint8List?>(
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
                    // Bytes corruptos (o no-imagen, p. ej. un PDF): mismo
                    // placeholder en vez del ícono roto de Flutter.
                    errorBuilder: (_, _, _) => _placeholder(),
                  );
                },
              ),
              _caption(),
              if (widget.selected) _selectedOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  /// Overlay de selección: tinte de la primaria sobre la celda + check en la
  /// esquina. Sólo visible cuando [MediaThumbnail.selected].
  Widget _selectedOverlay() => const Positioned.fill(
    child: ColoredBox(
      color: AppTokens.primaryGlow,
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.all(AppTokens.sp1),
          child: Icon(Icons.check_circle, color: AppTokens.primary, size: 22),
        ),
      ),
    ),
  );

  /// Caption inferior con el [MediaAsset.displayName] (alias o, si vacío,
  /// filename) sobre un scrim degradado para legibilidad sobre cualquier
  /// imagen. Vacío ⇒ no se pinta nada.
  Widget _caption() {
    final name = widget.asset.displayName.trim();
    if (name.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp2,
          vertical: AppTokens.sp1,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0x00000000), Color(0xCC000000)],
          ),
        ),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
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
  /// contenido sobre la superficie de la card. El nombre del asset NO va aquí
  /// (lo aporta el caption inferior común a todas las miniaturas); las
  /// miniaturas reales de video/audio quedan diferidas, así que el ícono es la
  /// identidad visual del tipo.
  Widget _placeholder() {
    final asset = widget.asset;
    return Container(
      key: Key('media_thumbnail.placeholder.${asset.ref}'),
      color: AppTokens.surface2,
      alignment: Alignment.center,
      child: Icon(
        _iconFor(asset.contentType),
        color: AppTokens.text2,
        size: 28,
      ),
    );
  }

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
