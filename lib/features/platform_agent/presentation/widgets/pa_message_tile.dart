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
import '../../domain/entities/pa_attachment.dart';
import '../../domain/entities/pa_message.dart';
import '../../domain/entities/pa_tool_result.dart';
import 'pa_tool_cards.dart';

/// Renderiza un turno del hilo. user/assistant con texto ⇒ burbuja. Un turno
/// de assistant puro tool_calls (sin texto) ⇒ nada (la acción se cuenta con la
/// tarjeta del tool). Un turno `tool` ⇒ tarjeta: chip compacto "Usó {toolName}"
/// que, si el resultado trae detalle estructurado (changeset o error), expande
/// a mostrarlo. Un resultado `requires_confirmation` con `onConfirm` cableado ⇒
/// tarjeta interactiva que nombra los bots afectados y ofrece Confirmar/Cancelar.
class PaMessageTile extends StatelessWidget {
  const PaMessageTile({
    required this.message,
    this.onConfirm,
    this.showReasoning = true,
    super.key,
  });

  final PaMessage message;

  /// Acción al confirmar un requires_confirmation: la página reenvía una
  /// autorización por MessageSent (el LLM re-llama el tool con confirm=true).
  /// nil ⇒ la tarjeta de confirmación degrada a la de error genérica.
  final VoidCallback? onConfirm;

  /// Muestra el «Razonamiento» plegable sobre la burbuja del assistant. Se
  /// apaga cuando el turno se pinta agrupado en una traza (el razonamiento ya
  /// es un nodo de ella): la respuesta queda como burbuja limpia fuera del
  /// colapso.
  final bool showReasoning;

  @override
  Widget build(BuildContext context) {
    if (message.isTool) {
      final result = PaToolResult.parse(message.toolResultsRaw);
      if (result.requiresConfirmation && onConfirm != null) {
        return PaConfirmationCard(result: result, onConfirm: onConfirm!);
      }
      return PaExpandableToolCard(result: result);
    }
    if (message.isAssistant) {
      final hasThinking = showReasoning && message.thinking.isNotEmpty;
      final hasBody =
          message.content.isNotEmpty || message.attachments.isNotEmpty;
      if (!hasBody && !hasThinking) {
        return const SizedBox.shrink();
      }
      // Los documentos que el turno ENTREGÓ (deliver_document) viajan
      // adjuntos en la respuesta: mismo renderer compartido que los adjuntos
      // del operador, dentro de la misma burbuja que el texto.
      final assistantGallery = _imageGallery(message.attachments);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (hasThinking)
            ReasoningDisclosure(reasoning: message.thinking, keyId: message.id),
          if (hasBody)
            CopyableBubble(
              text: message.content,
              keyId: 'pa.${message.id}',
              child: ChatBubble(
                mine: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final att in message.attachments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppTokens.sp1),
                        child: AttachmentContent(
                          id: '${message.id}.${att.ref}',
                          mediaRef: att.ref,
                          mime: att.mime,
                          name: att.name,
                          url: att.url,
                          gallery: assistantGallery,
                          galleryIndex: assistantGallery?.indexWhere(
                            (g) => g.mediaRef == att.ref,
                          ),
                        ),
                      ),
                    if (message.content.isNotEmpty)
                      AssistantMarkdown(data: message.content),
                  ],
                ),
              ),
            ),
          MessageTimestamp(at: message.createdAt),
        ],
      );
    }
    // Adjuntos-imagen del mensaje, en orden: con más de uno, tocar cualquiera
    // abre un visor deslizable entre ellos en vez del visor de una sola foto.
    final imageGallery = _imageGallery(message.attachments);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CopyableBubble(
          text: message.content,
          keyId: 'pa.${message.id}',
          child: ChatBubble(
            mine: message.isUser,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Adjuntos con el renderer compartido de media (miniatura de
                // imagen, audio reproducible, tarjetas de video/documento). La
                // fuente primaria es la copia local en caché (la subida la
                // siembra); la URL firmada de preview del wire es el respaldo
                // para adjuntos de otro dispositivo o de historial previo. Sin
                // ninguna de las dos degrada a la tarjeta con nombre.
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
                // Una nota de voz reproduce inline (la copia local grabada en
                // este dispositivo, sembrada en caché al enviar) y, si el
                // server la transcribió, el texto abajo. El `content` crudo
                // no se pinta (es el marcador "[audio…]" o duplica el transcrito).
                if (message.isVoiceNote)
                  _VoiceNote(message: message)
                else if (message.content.isNotEmpty)
                  Text(
                    message.content,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppTokens.text1),
                  ),
              ],
            ),
          ),
        ),
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

  final PaMessage message;

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
List<GalleryMediaItem>? _imageGallery(List<PaAttachment> attachments) {
  final images = attachments
      .where((a) => attachmentKindForMime(a.mime) == AttachmentKind.image)
      .toList();
  if (images.length < 2) return null;
  return images
      .map((a) => GalleryMediaItem(mediaRef: a.ref, url: a.url))
      .toList();
}
