import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/repositories/media_opener.dart';
import 'video_playback.dart';

/// Cota de la burbuja de video (póster 16:9).
const double _videoWidth = 240;
const double _videoHeight = 135;

/// Burbuja de video: póster oscuro con un botón de play centrado y una etiqueta
/// "Video". Al tocarla abre el reproductor a pantalla completa DENTRO de la app
/// ([VideoPlayback]). No muestra el primer fotograma real (extraerlo por cada
/// ítem de la lista sería costoso): el fotograma se ve en el reproductor.
class VideoCard extends StatelessWidget {
  const VideoCard({required this.id, required this.url, super.key});

  final String id;
  final String url;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      child: GestureDetector(
        key: Key('message.video.$id'),
        behavior: HitTestBehavior.opaque,
        onTap: () => context.read<VideoPlayback>().open(context, url: url),
        child: Container(
          width: _videoWidth,
          height: _videoHeight,
          color: AppTokens.surface2,
          child: Stack(
            children: <Widget>[
              const Center(
                child: Icon(
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
