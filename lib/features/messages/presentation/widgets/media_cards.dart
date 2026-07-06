import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../data/cache/message_media_cache.dart';
import '../../domain/repositories/media_opener.dart';
import 'video_playback.dart';

/// Cota de la burbuja de video (póster 16:9).
const double _videoWidth = 240;
const double _videoHeight = 135;

/// Burbuja de video: póster oscuro con un botón de play centrado y una etiqueta
/// "Video". Al tocarla resuelve los bytes por `mediaRef` desde la caché en disco
/// ([MessageMediaCache], cache-first: descarga UNA vez y persiste — el mismo
/// patrón de imagen/audio) y abre el reproductor a pantalla completa DENTRO de
/// la app ([VideoPlayback]); sin bytes cae al streaming de la URL firmada. No
/// muestra el primer fotograma real (extraerlo por cada ítem de la lista sería
/// costoso): el fotograma se ve en el reproductor.
class VideoCard extends StatefulWidget {
  const VideoCard({
    required this.cache,
    required this.id,
    required this.mediaRef,
    required this.url,
    super.key,
  });

  final MessageMediaCache cache;
  final String id;

  /// Identidad estable del video (clave de la caché en disco); `null` en filas
  /// viejas sin ref — sólo queda el streaming por URL.
  final String? mediaRef;

  /// URL firmada de respaldo (descarga/streaming). `null` con la firma caída:
  /// la copia local igual reproduce.
  final String? url;

  @override
  State<VideoCard> createState() => VideoCardState();
}

class VideoCardState extends State<VideoCard> {
  /// Resolviendo bytes (descarga de un video aún sin caché): spinner sobre el
  /// play en vez de un toque muerto.
  bool _resolving = false;

  /// Resuelve la copia local (o cae a la URL) y abre el reproductor. Sin
  /// fuente alguna (offline sin caché y sin firma) avisa en vez de callar.
  Future<void> _onTap() async {
    if (_resolving) return;
    final playback = context.read<VideoPlayback>();
    final messenger = ScaffoldMessenger.of(context);
    final ref = widget.mediaRef;
    Uint8List? bytes;
    if (ref != null) {
      setState(() => _resolving = true);
      try {
        bytes = await widget.cache.bytesFor(ref, widget.url);
      } catch (_) {
        bytes = null;
      }
      if (!mounted) return;
      setState(() => _resolving = false);
    }
    if (bytes == null && widget.url == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No se pudo reproducir el video')),
        );
      return;
    }
    if (!mounted) return;
    await playback.open(context, url: widget.url, bytes: bytes, cacheKey: ref);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Semantics inline (misma convención que app_button): el área de tap del
    // video se anuncia como botón con acción legible.
    return Semantics(
      button: true,
      label: 'Reproducir video',
      // El rótulo interno "Video" es decorativo (duplicaría el anuncio).
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        child: GestureDetector(
          key: Key('message.video.${widget.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: Container(
            width: _videoWidth,
            height: _videoHeight,
            color: AppTokens.surface2,
            child: Stack(
              children: <Widget>[
                Center(
                  child: _resolving
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTokens.primary,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.play_circle_fill,
                          size: 56,
                          color: Colors.white70,
                        ),
                ),
                Positioned(
                  left: AppTokens.sp2,
                  bottom: AppTokens.sp2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.videocam_outlined,
                        size: 16,
                        color: AppTokens.text1,
                      ),
                      const SizedBox(width: AppTokens.sp1),
                      Text(
                        'Video',
                        style: textTheme.labelSmall?.copyWith(
                          color: AppTokens.text1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de documento: nombre de archivo real + ícono por extensión. Con URL
/// firmada descarga y abre con la app externa del sistema (estado "abriendo" +
/// SnackBar ante fallo); sin URL sólo informa (no es tocable). Nombre vacío ⇒
/// etiqueta genérica "Documento".
class DocumentCard extends StatefulWidget {
  const DocumentCard({
    required this.id,
    required this.url,
    required this.filename,
    super.key,
  });

  final String id;
  final String? url;
  final String filename;

  @override
  State<DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<DocumentCard> {
  bool _opening = false;

  Future<void> _open() async {
    final url = widget.url;
    if (_opening || url == null) return;
    final opener = context.read<MediaOpener>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _opening = true);
    try {
      await opener.open(url: url);
    } catch (_) {
      // Cualquier fallo (descarga, escritura a caché, sin app que abra) muestra
      // el mismo aviso: la acción prometida no debe fallar en silencio.
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el archivo')),
      );
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = widget.filename.trim();
    final label = name.isEmpty ? 'Documento' : name;
    final canOpen = widget.url != null;
    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp3,
        vertical: AppTokens.sp2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_opening)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTokens.chatAccent),
              ),
            )
          else
            Icon(documentIconFor(name), size: 20, color: AppTokens.chatAccent),
          const SizedBox(width: AppTokens.sp2),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(color: AppTokens.text1),
                ),
                Text(
                  _opening
                      ? 'Abriendo…'
                      : (canOpen ? 'Toca para abrir' : 'No disponible'),
                  style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
                ),
              ],
            ),
          ),
          if (canOpen) ...<Widget>[
            const SizedBox(width: AppTokens.sp2),
            const Icon(Icons.open_in_new, size: 16, color: AppTokens.text2),
          ],
        ],
      ),
    );
    // Sin URL firmada la tarjeta sólo informa: contenedor plano, no tocable.
    if (!canOpen) {
      return Container(
        decoration: BoxDecoration(
          color: AppTokens.bgBase.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        ),
        child: body,
      );
    }
    return Material(
      color: AppTokens.bgBase.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      child: InkWell(
        key: Key('message.doc.${widget.id}'),
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        onTap: _open,
        child: body,
      ),
    );
  }
}

/// Ícono por extensión del nombre de archivo (heurística ligera). Sin extensión
/// reconocida cae a un ícono genérico de documento.
IconData documentIconFor(String filename) {
  final dot = filename.lastIndexOf('.');
  final ext = dot >= 0 ? filename.substring(dot + 1).toLowerCase() : '';
  return switch (ext) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'doc' || 'docx' || 'rtf' || 'txt' => Icons.description_outlined,
    'xls' || 'xlsx' || 'csv' => Icons.table_chart_outlined,
    'ppt' || 'pptx' => Icons.slideshow_outlined,
    'zip' || 'rar' || '7z' => Icons.folder_zip_outlined,
    _ => Icons.insert_drive_file_outlined,
  };
}
