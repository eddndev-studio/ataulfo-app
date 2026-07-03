import 'dart:convert';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/util/image_aspect.dart';
import '../../data/cache/message_media_cache.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/media_opener.dart';
import 'audio_message_content.dart';
import 'media_viewer.dart';
import 'video_playback.dart';

/// Contenido de un mensaje no-texto del hilo, interaccionable como en
/// mensajería:
///
///   - imagen: miniatura recortada (servida por `mediaRef` desde la caché en
///     disco); tap → visor fullscreen.
///   - sticker: se pinta transparente a tamaño natural, sin burbuja ni tap
///     (es un glifo del mensaje, no una foto que se amplíe).
///   - audio/ptt: burbuja reproducible inline ([ThreadAudioCubit]).
///   - video: burbuja con play; reproduce a pantalla completa DENTRO de la app
///     ([VideoPlayback]).
///   - documento: tarjeta con el nombre de archivo; con URL firmada abre con
///     una app externa ([MediaOpener]).
///
/// Sin `mediaUrl` (firma caída, R2 sin configurar) todo degrada a la tarjeta
/// de tipo no interaccionable. Si la media trae caption, se pinta debajo.
class MessageMediaContent extends StatelessWidget {
  const MessageMediaContent({required this.message, super.key});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final m = message;
    final url = m.mediaUrl;
    final mediaRef = m.mediaRef;
    final media = switch (m.type) {
      // La imagen/sticker se sirve por `mediaRef` desde la caché en disco
      // (offline / firma expirada); `mediaUrl` sólo se usa para bajarla una vez.
      'image' || 'sticker' when mediaRef != null => _MessageImage(
        cache: context.read<MessageMediaCache>(),
        mediaRef: mediaRef,
        mediaUrl: url,
        id: m.externalId,
        sticker: m.type == 'sticker',
      ),
      'image' => _typedCard(context, Icons.image_outlined, 'Imagen'),
      'sticker' => _typedCard(
        context,
        Icons.emoji_emotions_outlined,
        'Sticker',
      ),
      // La nota se sirve por `mediaRef` desde la copia local (cacheada al
      // enviar / descargada una vez al recibir): la burbuja aparece de
      // inmediato y suena aunque la URL firmada aún no haya llegado; `url` sólo
      // es respaldo de streaming.
      'audio' || 'ptt' when mediaRef != null => AudioMessageContent(
        id: m.externalId,
        mediaRef: mediaRef,
        url: url,
        ptt: m.type == 'ptt',
      ),
      // Sin `mediaRef` (no debería pasar en media real): tarjeta de tipo. La
      // nota de voz se nombra como tal; el audio genérico como archivo.
      'ptt' => _typedCard(context, Icons.mic_none_outlined, 'Nota de voz'),
      'audio' => _typedCard(context, Icons.mic_none_outlined, 'Audio'),
      // El video con URL firmada se pinta como burbuja con play y reproduce
      // DENTRO de la app; sin URL cae a la tarjeta de tipo (no reproducible).
      'video' when url != null => _VideoCard(id: m.externalId, url: url),
      'video' => _typedCard(context, Icons.videocam_outlined, 'Video'),
      // El documento se pinta como tarjeta con su nombre de archivo real (el
      // wire lo manda en `content`) + ícono por extensión; con URL firmada la
      // tarjeta descarga y abre con la app externa, sin ella sólo informa.
      'document' => _DocumentCard(
        id: m.externalId,
        url: url,
        filename: m.content,
      ),
      // Tipos ricos (S25): la fila declara el tipo; el contenido legible
      // (nombre del lugar, del contacto, texto del voto) va como caption
      // debajo por el camino estándar.
      'location' => _typedCard(context, Icons.place_outlined, 'Ubicación'),
      'contact' => _typedCard(context, Icons.person_outline, 'Contacto'),
      'poll_vote' => _typedCard(context, Icons.how_to_vote_outlined, 'Voto'),
      // La encuesta persiste su JSON completo en content: la tarjeta lo
      // parsea (pregunta + opciones) y el caption crudo NO se repite.
      'poll' => _PollCard(id: m.externalId, rawContent: m.content),
      _ => Text(
        '[${m.type}]',
        style: textTheme.bodyLarge?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      ),
    };
    // El documento pinta su nombre DENTRO de la tarjeta (el wire manda el
    // nombre de archivo en `content`), y la encuesta parsea su JSON: en
    // ambos, repetir `content` como caption sería ruido (o un blob crudo).
    if (m.content.isEmpty || m.type == 'document' || m.type == 'poll') {
      return media;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        media,
        const SizedBox(height: AppTokens.sp1),
        Text(m.content, style: textTheme.bodyLarge),
      ],
    );
  }
}

/// Tarjeta de tipo para media sin URL firmada (o tipo no interaccionable):
/// ícono en el verde de sección + etiqueta legible.
Widget _typedCard(BuildContext context, IconData icon, String label) {
  final textTheme = Theme.of(context).textTheme;
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppTokens.sp3,
      vertical: AppTokens.sp2,
    ),
    decoration: BoxDecoration(
      color: AppTokens.bgBase.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 20, color: AppTokens.chatAccent),
        const SizedBox(width: AppTokens.sp2),
        // Flexible + elipsis: en un slot angosto (p. ej. el cuadro del sticker)
        // la etiqueta se recorta en vez de desbordar la fila.
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text1),
          ),
        ),
      ],
    ),
  );
}

/// Cota del cuadro de carga de la foto (spinner/placeholder) y cota del sticker
/// (que se pinta a tamaño natural DENTRO de esa caja, sin recorte). La foto ya
/// resuelta se pinta a su relación de aspecto real dentro de una caja acotada
/// por [_photoMaxWidth]×[_photoMaxHeight].
const double _photoSide = 220;
const double _stickerMaxSide = 140;
const double _photoMaxWidth = 240;
const double _photoMaxHeight = 320;

/// La relación de aspecto se acota a un rango usable: una foto extremadamente
/// ancha (panorama) o alta no debe colapsar la burbuja a una tira de pocos
/// píxeles. Fuera del rango se recorta al tocar (el visor muestra la completa).
const double _photoMinAspect = 0.5;
const double _photoMaxAspect = 2.5;

/// Miniatura de imagen/sticker servida por `mediaRef` desde la caché en disco
/// ([MessageMediaCache]): se ve offline y sobrevive a la expiración de la firma.
/// Mientras resuelve muestra un spinner; sin bytes (offline sin caché / firma
/// caída) cae a la tarjeta "no disponible". La imagen abre un visor fullscreen
/// al tocarla; el sticker no (es un glifo del mensaje, no una foto).
class _MessageImage extends StatefulWidget {
  const _MessageImage({
    required this.cache,
    required this.mediaRef,
    required this.mediaUrl,
    required this.id,
    required this.sticker,
  });

  final MessageMediaCache cache;
  final String mediaRef;
  final String? mediaUrl;
  final String id;
  final bool sticker;

  @override
  State<_MessageImage> createState() => _MessageImageState();
}

class _MessageImageState extends State<_MessageImage> {
  Uint8List? _bytes;

  /// Relación de aspecto (ancho/alto) de la foto ya resuelta; `null` mientras no
  /// resuelve, para un sticker, o si el decode falló (cae a un cuadro).
  double? _aspect;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_MessageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El widget se recicla al hacer scroll (mismo slot, otra imagen): si cambió
    // el ref, olvida los bytes viejos y recarga.
    if (oldWidget.mediaRef != widget.mediaRef) {
      _bytes = null;
      _aspect = null;
      _resolved = false;
      _load();
    } else if (_bytes == null && oldWidget.mediaUrl != widget.mediaUrl) {
      // Llegó la firma viva (p. ej. al reconectar) y aún no hay bytes: reintenta
      // ahora que hay de dónde bajar. (Con bytes ya en caché la URL es
      // irrelevante: la entrega es por disco.)
      _resolved = false;
      _load();
    }
  }

  Future<void> _load() async {
    final ref = widget.mediaRef;
    final b = await widget.cache.bytesFor(ref, widget.mediaUrl);
    // Si el slot se recicló a otro ref mientras cargaba, no pintes el viejo.
    if (!mounted || ref != widget.mediaRef) return;
    // La foto se resuelve junto a su relación de aspecto (leída del encabezado,
    // síncrona) en un solo setState: aparece ya con su forma real, sin un salto
    // de layout. El sticker no la usa (se pinta a tamaño natural acotado).
    final aspect = (b != null && !widget.sticker) ? imageAspectRatio(b) : null;
    setState(() {
      _bytes = b;
      _aspect = aspect;
      _resolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    if (b != null) {
      return widget.sticker ? _stickerImage(b) : _photoImage(context, b);
    }
    final side = widget.sticker ? _stickerMaxSide : _photoSide;
    if (!_resolved) {
      return SizedBox(
        width: side,
        height: side,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
            ),
          ),
        ),
      );
    }
    return _typedCard(
      context,
      Icons.broken_image_outlined,
      widget.sticker ? 'Sticker no disponible' : 'Imagen no disponible',
    );
  }

  /// El sticker se pinta transparente y a tamaño natural dentro de un cuadro
  /// acotado: sin recorte, sin esquinas redondeadas y sin tap a visor.
  /// `scaleDown` respeta el tamaño natural y sólo encoge si excede la caja (no
  /// agranda un sticker chico volviéndolo borroso). La caja lleva medidas
  /// explícitas (como la miniatura de foto) para no depender del tamaño
  /// intrínseco, que en un `ListView` no está listo al primer layout.
  Widget _stickerImage(Uint8List b) => Image.memory(
    b,
    key: Key('message.sticker.${widget.id}'),
    width: _stickerMaxSide,
    height: _stickerMaxSide,
    fit: BoxFit.scaleDown,
    errorBuilder: (context, error, stack) => _typedCard(
      context,
      Icons.broken_image_outlined,
      'Sticker no disponible',
    ),
  );

  /// La imagen se pinta a su relación de aspecto real (esquinas redondeadas)
  /// dentro de una caja acotada; al tocarla abre el visor fullscreen con los
  /// bytes cacheados. Sin relación de aspecto (decode falló) cae a un cuadro
  /// para conservar un tamaño estable.
  Widget _photoImage(BuildContext context, Uint8List b) {
    final aspect = _aspect;
    final image = Image.memory(
      b,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => _typedCard(
        context,
        Icons.broken_image_outlined,
        'Imagen no disponible',
      ),
    );
    final Widget sized = aspect == null
        ? SizedBox(width: _photoSide, height: _photoSide, child: image)
        : ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _photoMaxWidth,
              maxHeight: _photoMaxHeight,
            ),
            child: AspectRatio(
              aspectRatio: aspect.clamp(_photoMinAspect, _photoMaxAspect),
              child: image,
            ),
          );
    return GestureDetector(
      key: Key('message.image.${widget.id}'),
      onTap: () => showMediaViewer(context, bytes: b, url: widget.mediaUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        child: sized,
      ),
    );
  }
}

/// Cota de la burbuja de video (póster 16:9).
const double _videoWidth = 240;
const double _videoHeight = 135;

/// Burbuja de video: póster oscuro con un botón de play centrado y una etiqueta
/// "Video". Al tocarla abre el reproductor a pantalla completa DENTRO de la app
/// ([VideoPlayback]). No muestra el primer fotograma real (extraerlo por cada
/// ítem de la lista sería costoso): el fotograma se ve en el reproductor.
class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.id, required this.url});

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

/// Tarjeta de documento: nombre de archivo real (el wire lo manda en `content`)
/// + ícono por extensión. Con URL firmada descarga y abre con la app externa
/// del sistema (estado "abriendo" + SnackBar ante fallo); sin URL sólo informa
/// (no es tocable). Nombre vacío ⇒ etiqueta genérica "Documento".
class _DocumentCard extends StatefulWidget {
  const _DocumentCard({
    required this.id,
    required this.url,
    required this.filename,
  });

  final String id;
  final String? url;
  final String filename;

  @override
  State<_DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<_DocumentCard> {
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
            Icon(_docIcon(name), size: 20, color: AppTokens.chatAccent),
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
IconData _docIcon(String filename) {
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


/// Tarjeta de encuesta: parsea el JSON persistido `{question, options,
/// multiple}` y pinta pregunta + opciones con su ícono de selección. La
/// votación ocurre en el WhatsApp del cliente; aquí es representación.
class _PollCard extends StatelessWidget {
  const _PollCard({required this.id, required this.rawContent});

  final String id;
  final String rawContent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    String question;
    List<String> options;
    bool multiple;
    try {
      final decoded = jsonDecode(rawContent);
      final map = decoded as Map<String, dynamic>;
      question = map['question'] as String? ?? '';
      options = (map['options'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false);
      multiple = map['multiple'] as bool? ?? false;
    } on Object {
      // JSON ilegible (fila vieja o corrupta): degrada al blob crudo en
      // cursiva, nunca una burbuja vacía muda.
      return Text(
        rawContent,
        style: textTheme.bodyLarge?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      );
    }
    return Column(
      key: Key('message.poll.$id'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.poll_outlined, size: 18, color: AppTokens.primary),
            const SizedBox(width: AppTokens.sp2),
            Flexible(
              child: Text(
                question,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.sp2),
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.sp1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  multiple
                      ? Icons.check_box_outline_blank
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: AppTokens.text2,
                ),
                const SizedBox(width: AppTokens.sp2),
                Flexible(child: Text(o, style: textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
