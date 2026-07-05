import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/assistant_markdown.dart';
import '../../../../core/design/widgets/chat_bubble.dart';
import '../../../../core/design/widgets/copy_text_actions.dart';
import '../../../../core/design/widgets/message_timestamp.dart';
import '../../../../core/design/widgets/reasoning_disclosure.dart';
import '../../../messages/presentation/widgets/attachment_content.dart';
import '../../domain/entities/trainer_message.dart';
import 'trainer_change_card.dart';
import 'trainer_inspect_flow_card.dart';
import 'trainer_prompt_history_card.dart';
import 'trainer_tool_error_card.dart';

/// Ícono por MIME del adjunto (imagen/PDF; resto genérico).
IconData attachmentIcon(String mime) {
  if (mime.startsWith('image/')) return Icons.image_outlined;
  if (mime == 'application/pdf') return Icons.description_outlined;
  return Icons.attach_file;
}

/// Renderiza un turno del hilo del entrenador. Un turno `tool` se proyecta a la
/// tarjeta que corresponda (inspección, historial, error o cambio); las
/// lecturas sin efecto no rinden nada. user/assistant con texto ⇒ burbuja; un
/// assistant puro tool_calls (sin texto) ⇒ nada (la acción la cuenta la tarjeta).
class TrainerMessageTile extends StatelessWidget {
  const TrainerMessageTile({required this.message, super.key});

  final TrainerMessage message;

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
    final rawBubble = ChatBubble(
      mine: message.isUser,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Adjuntos con el renderer compartido de media (miniatura de imagen,
          // audio reproducible, tarjetas de video/documento). El wire del
          // entrenador no trae URL firmada: la fuente es la copia local que la
          // subida sembró en caché; sin ella degrada a la tarjeta con nombre.
          if (message.attachments.isNotEmpty) ...<Widget>[
            for (final att in message.attachments)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.sp1),
                child: AttachmentContent(
                  id: '${message.id}.${att.ref}',
                  mediaRef: att.ref,
                  mime: att.mime,
                  name: att.name,
                ),
              ),
          ],
          if (message.content.isNotEmpty)
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
        if (message.isAssistant && message.thinking.isNotEmpty)
          ReasoningDisclosure(reasoning: message.thinking, keyId: message.id),
        if (message.content.isNotEmpty || message.attachments.isNotEmpty)
          bubble,
        MessageTimestamp(at: message.createdAt),
      ],
    );
  }
}
