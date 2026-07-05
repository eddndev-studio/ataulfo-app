import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/assistant_markdown.dart';
import '../../../../core/design/widgets/chat_bubble.dart';
import '../../../../core/design/widgets/copy_text_actions.dart';
import '../../../../core/design/widgets/message_timestamp.dart';
import '../../../../core/design/widgets/reasoning_disclosure.dart';
import '../../domain/entities/pa_message.dart';
import 'pa_tool_cards.dart';

/// Renderiza un turno del hilo. user/assistant con texto ⇒ burbuja. Un turno
/// de assistant puro tool_calls (sin texto) ⇒ nada (la acción se cuenta con la
/// tarjeta del tool). Un turno `tool` ⇒ tarjeta: chip compacto "Usó {toolName}"
/// que, si el resultado trae detalle estructurado (changeset o error), expande
/// a mostrarlo. Un resultado `requires_confirmation` con `onConfirm` cableado ⇒
/// tarjeta interactiva que nombra los bots afectados y ofrece Confirmar/Cancelar.
class PaMessageTile extends StatelessWidget {
  const PaMessageTile({required this.message, this.onConfirm, super.key});

  final PaMessage message;

  /// Acción al confirmar un requires_confirmation: la página reenvía una
  /// autorización por MessageSent (el LLM re-llama el tool con confirm=true).
  /// nil ⇒ la tarjeta de confirmación degrada a la de error genérica.
  final VoidCallback? onConfirm;

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
      final hasThinking = message.thinking.isNotEmpty;
      if (message.content.isEmpty && !hasThinking) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (hasThinking)
            ReasoningDisclosure(reasoning: message.thinking, keyId: message.id),
          if (message.content.isNotEmpty)
            CopyableBubble(
              text: message.content,
              keyId: 'pa.${message.id}',
              child: ChatBubble(
                mine: false,
                child: AssistantMarkdown(data: message.content),
              ),
            ),
          MessageTimestamp(at: message.createdAt),
        ],
      );
    }
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
                for (final att in message.attachments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTokens.sp1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          paAttachmentIcon(att.mime),
                          size: 16,
                          color: AppTokens.text2,
                        ),
                        const SizedBox(width: AppTokens.sp1),
                        Flexible(
                          child: Text(
                            att.name,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppTokens.text2),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Una nota de voz se rotula honestamente: chip "Nota de voz" y,
                // si el server la transcribió, el texto abajo. El `content` crudo
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

/// Render honesto de una nota de voz del operador: rótulo "Nota de voz" con
/// ícono de micrófono y, cuando el server la transcribió (`transcriptStatus`
/// done y texto no vacío), el transcrito debajo. Nunca pinta el `content`
/// crudo, que es el marcador de audio o una copia del transcrito.
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.mic_none_outlined,
              size: 16,
              color: AppTokens.text2,
            ),
            const SizedBox(width: AppTokens.sp1),
            Text(
              'Nota de voz',
              style: textTheme.labelMedium?.copyWith(color: AppTokens.text2),
            ),
          ],
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

/// Ícono por MIME del adjunto (imagen/PDF; resto genérico).
IconData paAttachmentIcon(String mime) {
  if (mime.startsWith('image/')) return Icons.image_outlined;
  if (mime == 'application/pdf') return Icons.description_outlined;
  return Icons.attach_file;
}
