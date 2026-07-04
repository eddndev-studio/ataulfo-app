import 'dart:convert';

import '../../domain/entities/pa_attachment.dart';
import '../../domain/entities/pa_conversation.dart';
import '../../domain/entities/pa_message.dart';
import '../../domain/entities/pa_models.dart';
import '../../domain/entities/pa_progress.dart';

/// DTOs del asistente de plataforma (wire snake_case). Los canónicos fallan
/// loud (`FormatException`); los opcionales degradan a vacío (un wire con un
/// campo de más/menos no debe tumbar el chat).
class PaConversationDto {
  const PaConversationDto({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaConversationDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final createdAt = json['created_at'];
    final updatedAt = json['updated_at'];
    if (id is! String || createdAt is! String || updatedAt is! String) {
      throw const FormatException('pa conversation: shape inválido');
    }
    return PaConversationDto(
      id: id,
      title: json['title'] is String ? json['title'] as String : '',
      createdAt: DateTime.parse(createdAt).toUtc(),
      updatedAt: DateTime.parse(updatedAt).toUtc(),
    );
  }

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaConversation toEntity() => PaConversation(
    id: id,
    title: title,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

class PaMessageDto {
  const PaMessageDto({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.toolCallsRaw,
    this.toolResultsRaw,
    this.thinking = '',
    this.attachments = const <PaAttachmentDto>[],
  });

  factory PaMessageDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final conversationId = json['conversation_id'];
    final role = json['role'];
    final createdAt = json['created_at'];
    if (id is! String ||
        conversationId is! String ||
        role is! String ||
        createdAt is! String) {
      throw const FormatException('pa message: shape inválido');
    }
    // tool_calls/tool_results llegan como jsonb arbitrario: se re-serializan
    // a String para que la presentación los resuma sin que la capa de datos
    // fije su shape.
    String? raw(Object? v) => v == null ? null : jsonEncode(v);
    // attachments es aditivo y TOLERANTE: entradas malformadas se omiten
    // (el hilo no se cae por un adjunto raro del wire).
    final atts = <PaAttachmentDto>[];
    if (json['attachments'] is List<dynamic>) {
      for (final e in json['attachments'] as List<dynamic>) {
        if (e is! Map<String, dynamic>) continue;
        final att = PaAttachmentDto.tryParse(e);
        if (att != null) atts.add(att);
      }
    }
    return PaMessageDto(
      id: id,
      conversationId: conversationId,
      role: role,
      content: json['content'] is String ? json['content'] as String : '',
      toolCallsRaw: raw(json['tool_calls']),
      toolResultsRaw: raw(json['tool_results']),
      thinking: json['thinking'] is String ? json['thinking'] as String : '',
      attachments: atts,
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
  final List<PaAttachmentDto> attachments;
  final DateTime createdAt;

  PaMessage toEntity() => PaMessage(
    id: id,
    conversationId: conversationId,
    role: role,
    content: content,
    toolCallsRaw: toolCallsRaw,
    toolResultsRaw: toolResultsRaw,
    thinking: thinking,
    attachments: attachments.map((a) => a.toEntity()).toList(growable: false),
    createdAt: createdAt,
  );
}

/// DTO de un adjunto del hilo (mismo shape en la subida y en el mensaje).
class PaAttachmentDto {
  const PaAttachmentDto({
    required this.ref,
    required this.mime,
    required this.name,
    required this.sizeBytes,
  });

  /// Canónico para la respuesta de la SUBIDA (shape garantizado).
  factory PaAttachmentDto.fromJson(Map<String, dynamic> json) {
    final att = tryParse(json);
    if (att == null) {
      throw const FormatException('pa attachment: shape inválido');
    }
    return att;
  }

  /// Tolerante para las listas del hilo (malformado ⇒ null, se omite).
  static PaAttachmentDto? tryParse(Map<String, dynamic> json) {
    final ref = json['ref'];
    final mime = json['mime'];
    final name = json['name'];
    final size = json['sizeBytes'];
    if (ref is! String || mime is! String || name is! String || size is! num) {
      return null;
    }
    return PaAttachmentDto(
      ref: ref,
      mime: mime,
      name: name,
      sizeBytes: size.toInt(),
    );
  }

  final String ref;
  final String mime;
  final String name;
  final int sizeBytes;

  PaAttachment toEntity() =>
      PaAttachment(ref: ref, mime: mime, name: name, sizeBytes: sizeBytes);
}

/// DTO del `paWire` del SSE (camelCase — el adapter SSE emite ese shape).
/// `kind` y `conversationId` son canónicos (dirigen filtro y dispatch); el
/// resto degrada.
class PaProgressEventDto {
  const PaProgressEventDto({
    required this.kind,
    required this.conversationId,
    required this.at,
    this.runId = '',
    this.iteration = 0,
    this.model = '',
    this.toolName = '',
    this.toolError = false,
    this.error = '',
  });

  factory PaProgressEventDto.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    final conversationId = json['conversationId'];
    if (kind is! String || conversationId is! String) {
      throw const FormatException('pa progress: shape inválido');
    }
    final at = json['at'];
    return PaProgressEventDto(
      kind: kind,
      conversationId: conversationId,
      at: at is String ? DateTime.parse(at).toUtc() : DateTime(0),
      runId: json['runId'] is String ? json['runId'] as String : '',
      iteration: json['iteration'] is num
          ? (json['iteration'] as num).toInt()
          : 0,
      model: json['model'] is String ? json['model'] as String : '',
      toolName: json['toolName'] is String ? json['toolName'] as String : '',
      toolError: json['toolError'] == true,
      error: json['error'] is String ? json['error'] as String : '',
    );
  }

  final String kind;
  final String conversationId;
  final DateTime at;
  final String runId;
  final int iteration;
  final String model;
  final String toolName;
  final bool toolError;
  final String error;

  PaProgressEvent toEntity() => PaProgressEvent(
    kind: kind,
    conversationId: conversationId,
    at: at,
    runId: runId,
    iteration: iteration,
    model: model,
    toolName: toolName,
    toolError: toolError,
    error: error,
  );
}

/// DTO de GET `/platform-agent/models`. TOLERANTE de punta a punta (claves
/// ausentes ⇒ vacío): el selector es opcional y un wire inesperado (o un
/// backend sin la ruta) no debe tumbar el chat.
class PaModelsDto {
  const PaModelsDto({required this.options, required this.defaultId});

  factory PaModelsDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final options = <PaModelOption>[];
    if (raw is List<dynamic>) {
      for (final e in raw) {
        if (e is! Map<String, dynamic>) continue;
        final id = e['id'];
        final label = e['label'];
        if (id is String && id.isNotEmpty && label is String) {
          // Flags de modalidad DEFENSIVOS: solo se adoptan si el wire los trae
          // como bool. Ausentes ⇒ null (desconocido) y la UI no muestra aviso.
          final img = e['imageInput'];
          final pdf = e['pdfInput'];
          options.add(
            PaModelOption(
              id: id,
              label: label,
              imageInput: img is bool ? img : null,
              pdfInput: pdf is bool ? pdf : null,
            ),
          );
        }
      }
    }
    final def = json['default'];
    return PaModelsDto(options: options, defaultId: def is String ? def : '');
  }

  final List<PaModelOption> options;
  final String defaultId;

  PaModels toEntity() => PaModels(options: options, defaultId: defaultId);
}
