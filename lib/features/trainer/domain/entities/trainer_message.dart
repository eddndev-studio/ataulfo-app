import 'package:flutter/foundation.dart';

import 'trainer_attachment.dart';

/// Turno persistido del hilo del entrenador. `toolCallsRaw`/`toolResultsRaw`
/// conservan el jsonb CRUDO del wire: la capa de presentación los parsea
/// para las tarjetas de cambio (edit_prompt/write_doc/...), sin que la capa
/// de datos asuma su shape interno.
class TrainerMessage {
  const TrainerMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.toolCallsRaw,
    this.toolResultsRaw,
    this.thinking = '',
    this.attachments = const <TrainerAttachment>[],
  });

  final String id;
  final String conversationId;
  final String role; // user | assistant | tool
  final String content;
  final String? toolCallsRaw;
  final String? toolResultsRaw;
  final String thinking;
  final List<TrainerAttachment> attachments;
  final DateTime createdAt;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isTool => role == 'tool';

  @override
  bool operator ==(Object other) =>
      other is TrainerMessage &&
      other.id == id &&
      other.conversationId == conversationId &&
      other.role == role &&
      other.content == content &&
      other.toolCallsRaw == toolCallsRaw &&
      other.toolResultsRaw == toolResultsRaw &&
      other.thinking == thinking &&
      listEquals(other.attachments, attachments) &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    role,
    content,
    toolCallsRaw,
    toolResultsRaw,
    thinking,
    Object.hashAll(attachments),
    createdAt,
  );
}

/// Página DESC del historial + cursor opaco de la siguiente (vacío ⇒ fin).
class TrainerMessagesPage {
  const TrainerMessagesPage({required this.messages, required this.nextCursor});

  final List<TrainerMessage> messages;
  final String nextCursor;
}
