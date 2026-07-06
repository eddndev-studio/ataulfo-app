import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/media/attachment_kind.dart';
import '../../../../core/util/image_aspect.dart';
import '../../data/cache/message_media_cache.dart';
import 'audio_message_content.dart';
import 'media_cards.dart';
import 'media_viewer.dart';

/// Contenido interaccionable de UN adjunto descrito por primitivas del wire
/// (`ref` + MIME + nombre + URL firmada opcional), sin acoplarse a la entidad
/// de mensaje de ningún hilo. Es el núcleo compartido de los tres chats
/// (clientes, entrenador y asistente de plataforma): la clase se deriva del
/// MIME client-side y despacha al renderer correspondiente.
///
///   - imagen: miniatura desde la caché por ref (tap → visor fullscreen);
///     sin bytes ni URL degrada a la tarjeta con su nombre.
///   - audio: burbuja reproducible inline ([AudioMessageContent]).
///   - video: burbuja con play ([VideoCard]), cache-first por ref como
///     imagen/audio; sin bytes ni URL avisa recién al tocar.
///   - documento: tarjeta con nombre ([DocumentCard]); abre externo solo
///     con URL.
///
/// Requiere en contexto: [MessageMediaCache] (imagen), `ThreadAudioCubit`
/// (audio), `VideoPlayback` (video con URL) y `MediaOpener` (documento con
/// URL).
class AttachmentContent extends StatelessWidget {
  const AttachmentContent({
    required this.id,
    required this.mediaRef,
    required this.mime,
    required this.name,
    this.url,
    super.key,
  });

  /// Identidad estable del slot para las Keys de widget (p. ej.
  /// `mensajeId.ref`).
  final String id;

  /// Ref de la media (moneda del wire; clave de caché local).
  final String mediaRef;

  final String mime;

  /// Nombre de archivo legible: etiqueta de las degradaciones y de la tarjeta
  /// de documento.
  final String name;

  /// URL firmada de descarga/streaming; `null` cuando el wire no la trae
  /// (es best-effort: la firma puede fallar u omitirse): entonces solo sirve
  /// la copia local ya cacheada.
  final String? url;

  @override
  Widget build(BuildContext context) {
    final u = url;
    return switch (attachmentKindForMime(mime)) {
      AttachmentKind.image => AttachmentImage(
        cache: context.read<MessageMediaCache>(),
        mediaRef: mediaRef,
        mediaUrl: u,
        id: id,
        sticker: false,
        unavailableIcon: Icons.image_outlined,
        unavailableLabel: name,
      ),
      AttachmentKind.audio => AudioMessageContent(
        id: id,
        mediaRef: mediaRef,
        url: u,
        ptt: false,
        contentType: mime,
      ),
      // Cache-first por ref, como imagen/audio: la burbuja es reproducible
      // aunque la URL firmada esté ausente o expirada, mientras haya una
      // copia local; sin ninguna fuente, VideoCard avisa recién al tocar.
      AttachmentKind.video => VideoCard(
        cache: context.read<MessageMediaCache>(),
        id: id,
        mediaRef: mediaRef,
        url: u,
      ),
      AttachmentKind.document => DocumentCard(id: id, url: u, filename: name),
    };
  }
}

/// Tarjeta de tipo para media sin fuente interaccionable: ícono en el verde de
/// sección + etiqueta legible.
Widget mediaTypedCard(BuildContext context, IconData icon, String label) {
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
/// caída / adjunto de otro dispositivo) cae a la tarjeta de no-disponible
/// ([unavailableIcon] + [unavailableLabel]). La imagen abre un visor fullscreen
/// al tocarla; el sticker no (es un glifo del mensaje, no una foto).
class AttachmentImage extends StatefulWidget {
  const AttachmentImage({
    required this.cache,
    required this.mediaRef,
    required this.mediaUrl,
    required this.id,
    required this.sticker,
    this.unavailableIcon = Icons.broken_image_outlined,
    this.unavailableLabel,
    super.key,
  });

  final MessageMediaCache cache;
  final String mediaRef;
  final String? mediaUrl;
  final String id;
  final bool sticker;

  /// Ícono de la tarjeta de degradación (sin bytes / decode fallido).
  final IconData unavailableIcon;

  /// Etiqueta de la degradación; `null` cae a la copy genérica por tipo.
  final String? unavailableLabel;

  @override
  State<AttachmentImage> createState() => _AttachmentImageState();
}

class _AttachmentImageState extends State<AttachmentImage> {
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
  void didUpdateWidget(AttachmentImage oldWidget) {
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

  String get _fallbackLabel =>
      widget.unavailableLabel ??
      (widget.sticker ? 'Sticker no disponible' : 'Imagen no disponible');

  Widget _unavailableCard(BuildContext context) =>
      mediaTypedCard(context, widget.unavailableIcon, _fallbackLabel);

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
    final card = _unavailableCard(context);
    if (widget.sticker) return card;
    // Reintento manual (mismo patrón que el pendiente fallido del hilo): el
    // usuario no espera el TTL anti-martilleo ni el reciclado del widget.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        card,
        TextButton(
          key: Key('message.image.${widget.id}.retry'),
          onPressed: _retry,
          child: const Text('Reintentar'),
        ),
      ],
    );
  }

  /// Olvida el fallo cacheado y vuelve a resolver de verdad.
  void _retry() {
    widget.cache.retry(widget.mediaRef);
    setState(() => _resolved = false);
    _load();
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
    errorBuilder: (context, error, stack) => _unavailableCard(context),
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
      errorBuilder: (context, error, stack) => _unavailableCard(context),
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
    // Semantics inline (misma convención que app_button): el área de tap de
    // la foto se anuncia como botón con acción legible.
    return Semantics(
      button: true,
      label: 'Ver imagen',
      child: GestureDetector(
        key: Key('message.image.${widget.id}'),
        onTap: () => showMediaViewer(context, bytes: b, url: widget.mediaUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          child: sized,
        ),
      ),
    );
  }
}
