import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/assistant_markdown.dart';
import '../../../../core/design/widgets/chat_bubble.dart';
import '../../../../core/design/widgets/copy_text_actions.dart';
import '../../../../core/design/widgets/message_timestamp.dart';
import '../../../../core/design/widgets/reasoning_disclosure.dart';
import '../../../../core/media/attachment_kind.dart';
import '../../../messages/presentation/widgets/attachment_content.dart';
import '../../../messages/presentation/widgets/audio_message_content.dart';
import '../../../messages/presentation/widgets/media_viewer.dart';
import '../../domain/entities/trainer_attachment.dart';
import '../../domain/entities/trainer_message.dart';
import 'trainer_change_card.dart';
import 'trainer_inspect_flow_card.dart';
import 'trainer_prompt_history_card.dart';
import 'trainer_tool_error_card.dart';

/// Renderiza un turno del hilo del entrenador. Un turno `tool` se proyecta a la
/// tarjeta que corresponda (inspección, historial, error o cambio); las
/// lecturas sin efecto no rinden nada. user/assistant con texto ⇒ burbuja; un
/// assistant puro tool_calls (sin texto) ⇒ nada (la acción la cuenta la tarjeta).
class TrainerMessageTile extends StatelessWidget {
  const TrainerMessageTile({
    required this.message,
    this.showReasoning = true,
    super.key,
  });

  final TrainerMessage message;

  /// false ⇒ omite el [ReasoningDisclosure] del assistant: el turno agrupado
  /// ya pinta el razonamiento como nodo de su traza y duplicarlo estorba.
  final bool showReasoning;

  @override
  Widget build(BuildContext context) {
    if (message.isTool) {
      final inspect = TrainerInspectFlowData.fromMessage(message);
      if (inspect != null) {
        return TrainerInspectFlowCard(messageId: message.id, data: inspect);
      }
      final history = TrainerPromptHistoryData.fromMessage(message);
      if (history != null) {
        return TrainerPromptHistoryCard(messageId: message.id, data: history);
      }
      final err = TrainerToolErrorData.fromMessage(message);
      if (err != null) {
        return TrainerToolErrorCard(messageId: message.id, data: err);
      }
      final card = TrainerChangeCardData.fromMessage(message);
      if (card == null) return const SizedBox.shrink();
      return TrainerChangeCard(messageId: message.id, data: card);
    }
    if (message.isAssistant &&
        message.content.isEmpty &&
        message.thinking.isEmpty) {
      // Turno puro tool_calls: la acción se cuenta con la tarjeta del tool
      // result; una burbuja vacía solo mete ruido.
      return const SizedBox.shrink();
    }
    // Adjuntos-imagen del mensaje, en orden: con más de uno, tocar cualquiera
    // abre un visor deslizable entre ellos en vez del visor de una sola foto.
    final imageGallery = _imageGallery(message.attachments);
    final rawBubble = ChatBubble(
      mine: message.isUser,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Adjuntos con el renderer compartido de media (miniatura de imagen,
          // audio reproducible, tarjetas de video/documento). La fuente
          // primaria es la copia local en caché (la subida la siembra); la URL
          // firmada de preview del wire es el respaldo para adjuntos de otro
          // dispositivo o de historial previo. Sin ninguna de las dos degrada
          // a la tarjeta con nombre.
          if (message.attachments.isNotEmpty) ...<Widget>[
            for (final att in message.attachments)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.sp1),
                child: AttachmentContent(
                  id: '${message.id}.${att.ref}',
                  mediaRef: att.ref,
                  mime: att.mime,
                  name: att.name,
                  url: att.url,
                  gallery: imageGallery,
                  galleryIndex: imageGallery?.indexWhere(
                    (g) => g.mediaRef == att.ref,
                  ),
                ),
              ),
          ],
          // Una nota de voz reproduce inline (la copia local grabada en este
          // dispositivo, sembrada en caché al enviar) y, si el server la
          // transcribió, el texto abajo. El `content` crudo no se pinta (es
          // el marcador "[audio…]" o duplica el transcrito).
          if (message.isVoiceNote)
            _VoiceNote(message: message)
          else if (message.content.isNotEmpty)
            message.isAssistant
                ? AssistantMarkdown(data: message.content)
                : Text(
                    message.content,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppTokens.text1),
                  ),
        ],
      ),
    );
    // Long-press para copiar/seleccionar el texto del turno (vacío en burbujas
    // sólo-adjunto: el wrapper no engancha el gesto).
    final bubble = CopyableBubble(
      text: message.content,
      keyId: 'trainer.${message.id}',
      child: rawBubble,
    );
    // El razonamiento del assistant (si viaja) va colapsado SOBRE la burbuja;
    // la hora del turno, debajo y del lado del emisor.
    return Column(
      crossAxisAlignment: message.isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showReasoning && message.isAssistant && message.thinking.isNotEmpty)
          ReasoningDisclosure(reasoning: message.thinking, keyId: message.id),
        if (message.content.isNotEmpty ||
            message.attachments.isNotEmpty ||
            message.isVoiceNote)
          bubble,
        MessageTimestamp(at: message.createdAt),
      ],
    );
  }
}

/// Nota de voz del operador: burbuja de audio reproducible inline (la fuente
/// primaria es la copia local en caché —la grabación de este dispositivo—;
/// la URL firmada de preview del wire es el respaldo de streaming para notas
/// de otro dispositivo o de historial previo) y, cuando el server la
/// transcribió (`transcriptStatus` done y texto no vacío), el transcrito
/// debajo. Nunca pinta el `content` crudo, que es el marcador de audio o una
/// copia del transcrito.
class _VoiceNote extends StatelessWidget {
  const _VoiceNote({required this.message});

  final TrainerMessage message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasTranscript =
        message.transcriptStatus == 'done' && message.transcript.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AudioMessageContent(
          id: message.id,
          mediaRef: message.audioRef,
          url: message.audioUrl.isEmpty ? null : message.audioUrl,
          ptt: true,
        ),
        if (hasTranscript) ...<Widget>[
          const SizedBox(height: AppTokens.sp1),
          Text(
            message.transcript,
            style: textTheme.bodyLarge?.copyWith(color: AppTokens.text1),
          ),
        ],
      ],
    );
  }
}

/// Adjuntos-imagen de [attachments], en orden, listos para el visor
/// deslizable; `null` con menos de dos (el visor de una sola imagen ya cubre
/// ese caso, sin cambio de comportamiento).
List<GalleryMediaItem>? _imageGallery(List<TrainerAttachment> attachments) {
  final images = attachments
      .where((a) => attachmentKindForMime(a.mime) == AttachmentKind.image)
      .toList();
  if (images.length < 2) return null;
  return images
      .map((a) => GalleryMediaItem(mediaRef: a.ref, url: a.url))
      .toList();
}
