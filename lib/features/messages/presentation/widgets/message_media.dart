import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../data/cache/message_media_cache.dart';
import '../../domain/entities/message.dart';
import 'attachment_content.dart';
import 'audio_message_content.dart';
import 'media_cards.dart';

/// Contenido de un mensaje no-texto del hilo de clientes, interaccionable como
/// en mensajería. Los renderers de media (imagen/audio/video/documento) son el
/// núcleo compartido con los hilos de agentes ([AttachmentContent] y piezas):
/// aquí solo se despacha por el `type` del wire, que trae tipos propios del
/// canal (sticker, encuesta, ubicación…) que los agentes no tienen.
///
///   - imagen: miniatura recortada (servida por `mediaRef` desde la caché en
///     disco); tap → visor fullscreen.
///   - sticker: se pinta transparente a tamaño natural, sin burbuja ni tap
///     (es un glifo del mensaje, no una foto que se amplíe).
///   - audio/ptt: burbuja reproducible inline ([AudioMessageContent]).
///   - video: burbuja con play; reproduce a pantalla completa DENTRO de la app.
///   - documento: tarjeta con el nombre de archivo; con URL firmada abre con
///     una app externa.
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
      'image' || 'sticker' when mediaRef != null => AttachmentImage(
        cache: context.read<MessageMediaCache>(),
        mediaRef: mediaRef,
        mediaUrl: url,
        id: m.externalId,
        sticker: m.type == 'sticker',
      ),
      'image' => mediaTypedCard(context, Icons.image_outlined, 'Imagen'),
      'sticker' => mediaTypedCard(
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
      'ptt' => mediaTypedCard(context, Icons.mic_none_outlined, 'Nota de voz'),
      'audio' => mediaTypedCard(context, Icons.mic_none_outlined, 'Audio'),
      // El video con URL firmada se pinta como burbuja con play y reproduce
      // DENTRO de la app; sin URL cae a la tarjeta de tipo (no reproducible).
      'video' when url != null => VideoCard(id: m.externalId, url: url),
      'video' => mediaTypedCard(context, Icons.videocam_outlined, 'Video'),
      // El documento se pinta como tarjeta con su nombre de archivo real (el
      // wire lo manda en `content`) + ícono por extensión; con URL firmada la
      // tarjeta descarga y abre con la app externa, sin ella sólo informa.
      'document' => DocumentCard(
        id: m.externalId,
        url: url,
        filename: m.content,
      ),
      // Tipos ricos (S25): la fila declara el tipo; el contenido legible
      // (nombre del lugar, del contacto, texto del voto) va como caption
      // debajo por el camino estándar.
      'location' => mediaTypedCard(context, Icons.place_outlined, 'Ubicación'),
      'contact' => mediaTypedCard(context, Icons.person_outline, 'Contacto'),
      'poll_vote' => mediaTypedCard(
        context,
        Icons.how_to_vote_outlined,
        'Voto',
      ),
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
