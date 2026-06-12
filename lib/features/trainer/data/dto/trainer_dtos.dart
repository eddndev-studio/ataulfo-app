import 'dart:convert';

import '../../domain/entities/trainer_conversation.dart';
import '../../domain/entities/trainer_message.dart';
import '../../domain/entities/trainer_models.dart';

/// DTOs del hilo del entrenador (wire snake_case, espejo del platform
/// agent). Los canónicos fallan loud; content es tolerante (assistant puro
/// tool_calls viaja sin content por contrato).
class TrainerConversationDto {
  const TrainerConversationDto({
    required this.id,
    required this.templateId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TrainerConversationDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final templateId = json['template_id'];
    final createdAt = json['created_at'];
    final updatedAt = json['updated_at'];
    if (id is! String ||
        templateId is! String ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException('trainer conversation: shape inválido');
    }
    return TrainerConversationDto(
      id: id,
      templateId: templateId,
      title: json['title'] is String ? json['title'] as String : '',
      createdAt: DateTime.parse(createdAt).toUtc(),
      updatedAt: DateTime.parse(updatedAt).toUtc(),
    );
  }

  final String id;
  final String templateId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  TrainerConversation toEntity() => TrainerConversation(
    id: id,
    templateId: templateId,
    title: title,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

class TrainerMessageDto {
  const TrainerMessageDto({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.toolCallsRaw,
    this.toolResultsRaw,
    this.thinking = '',
  });

  factory TrainerMessageDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final conversationId = json['conversation_id'];
    final role = json['role'];
    final createdAt = json['created_at'];
    if (id is! String ||
        conversationId is! String ||
        role is! String ||
        createdAt is! String) {
      throw const FormatException('trainer message: shape inválido');
    }
    // tool_calls/tool_results llegan como jsonb arbitrario: se re-serializan
    // a String para que la presentación los parsee sin que la capa de datos
    // fije su shape.
    String? raw(Object? v) => v == null ? null : jsonEncode(v);
    return TrainerMessageDto(
      id: id,
      conversationId: conversationId,
      role: role,
      content: json['content'] is String ? json['content'] as String : '',
      toolCallsRaw: raw(json['tool_calls']),
      toolResultsRaw: raw(json['tool_results']),
      thinking: json['thinking'] is String ? json['thinking'] as String : '',
      createdAt: DateTime.parse(createdAt).toUtc(),
    );
  }

  final String id;
  final String conversationId;
  final String role;
  final String content;
  final String? toolCallsRaw;
  final String? toolResultsRaw;
  final String thinking;
  final DateTime createdAt;

  TrainerMessage toEntity() => TrainerMessage(
    id: id,
    conversationId: conversationId,
    role: role,
    content: content,
    toolCallsRaw: toolCallsRaw,
    toolResultsRaw: toolResultsRaw,
    thinking: thinking,
    createdAt: createdAt,
  );
}

/// DTO de GET `/templates/{id}/trainer/models`. TOLERANTE de punta a punta
/// (claves ausentes ⇒ vacío): la feature del selector es opcional y un wire
/// inesperado no debe tumbar el chat del entrenador.
class TrainerModelsDto {
  const TrainerModelsDto({required this.options, required this.defaultId});

  factory TrainerModelsDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final options = <TrainerModelOption>[];
    if (raw is List<dynamic>) {
      for (final e in raw) {
        if (e is! Map<String, dynamic>) continue;
        final id = e['id'];
        final label = e['label'];
        if (id is String && id.isNotEmpty && label is String) {
          options.add(TrainerModelOption(id: id, label: label));
        }
      }
    }
    final def = json['default'];
    return TrainerModelsDto(
      options: options,
      defaultId: def is String ? def : '',
    );
  }

  final List<TrainerModelOption> options;
  final String defaultId;

  TrainerModels toEntity() =>
      TrainerModels(options: options, defaultId: defaultId);
}
