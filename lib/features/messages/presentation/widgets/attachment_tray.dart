import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';

/// Un adjunto elegido y aún NO enviado: los bytes locales (para la miniatura y
/// la subida), el nombre original y el `type` de envío ya inferido
/// (`image`/`video`/`audio`/`document`). Vive en la bandeja del composer hasta
/// que el lote se despacha.
class PendingAttachment {
  const PendingAttachment({
    required this.bytes,
    required this.filename,
    required this.type,
  });

  final Uint8List bytes;
  final String filename;
  final String type;

  bool get isImage => type == 'image';
  int get sizeBytes => bytes.length;
}

/// Bandeja de adjuntos pendientes sobre el composer del hilo: una tira
/// horizontal de tarjetas (miniatura real para imágenes desde los bytes
/// locales; ícono + nombre + peso para el resto) con un botón de quitar por
/// ítem y un contador. Mientras el lote se sube, oculta los quitar y muestra el
/// progreso `n/total`.
class AttachmentTray extends StatelessWidget {
  const AttachmentTray({
    super.key,
    required this.items,
    required this.onRemove,
    this.uploading = false,
    this.uploadedCount = 0,
  });

  /// Adjuntos en el orden en que se despacharán.
  final List<PendingAttachment> items;

  /// Quita el adjunto en [index] de la bandeja.
  final void Function(int index) onRemove;

  /// El lote se está subiendo: deshabilita quitar y muestra progreso.
  final bool uploading;

  /// Cuántos del lote ya se subieron (para el progreso `n/total`).
  final int uploadedCount;

  static const double _cardSize = 72;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const Key('composer.attachment_tray'),
      color: AppTokens.surface1,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp3,
        vertical: AppTokens.sp2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.sp2),
            child: Text(
              uploading
                  ? 'Subiendo $uploadedCount/${items.length}…'
                  : _counterLabel(items.length),
              style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
            ),
          ),
          SizedBox(
            height: _cardSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppTokens.sp2),
              itemBuilder: (context, index) => _AttachmentCard(
                key: Key('composer.attachment_tray.item.$index'),
                attachment: items[index],
                size: _cardSize,
                onRemove: uploading ? null : () => onRemove(index),
                removeKey: Key('composer.attachment_tray.item.$index.remove'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _counterLabel(int n) => n == 1 ? '1 archivo' : '$n archivos';
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    super.key,
    required this.attachment,
    required this.size,
    required this.onRemove,
    required this.removeKey,
  });

  final PendingAttachment attachment;
  final double size;
  final VoidCallback? onRemove;
  final Key removeKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusChip),
              child: attachment.isImage
                  ? Image.memory(
                      attachment.bytes,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      // Bytes no decodificables (formato exótico/corrupto): cae
                      // a la cara de archivo en vez de tumbar el composer.
                      errorBuilder: (_, _, _) =>
                          _FileFace(attachment: attachment),
                    )
                  : _FileFace(attachment: attachment),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                key: removeKey,
                onTap: onRemove,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppTokens.bgBase,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: AppTokens.text1,
                    semanticLabel: 'Quitar adjunto',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cara de una tarjeta no-imagen: ícono por familia + nombre + peso.
class _FileFace extends StatelessWidget {
  const _FileFace({required this.attachment});

  final PendingAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      color: AppTokens.surface3,
      padding: const EdgeInsets.all(AppTokens.sp1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(_iconFor(attachment.type), size: 22, color: AppTokens.text1),
          const SizedBox(height: 2),
          Text(
            attachment.filename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textTheme.labelSmall?.copyWith(
              color: AppTokens.text1,
              fontSize: 9,
            ),
          ),
          Text(
            _formatBytes(attachment.sizeBytes),
            style: textTheme.labelSmall?.copyWith(
              color: AppTokens.text2,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(String type) => switch (type) {
  'video' => Icons.videocam_outlined,
  'audio' => Icons.audiotrack_outlined,
  _ => Icons.insert_drive_file_outlined,
};

/// Peso legible: B / KB / MB (base 1024). Los documentos y clips muestran
/// tamaño; las imágenes ya se ven por su miniatura.
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
