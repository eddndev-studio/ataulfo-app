import 'dart:convert';

import '../../domain/entities/trainer_attachment.dart';
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
    this.attachments = const <TrainerAttachmentDto>[],
    this.audioRef = '',
    this.audioUrl = '',
    this.transcriptStatus = '',
    this.transcript = '',
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
    // attachments es aditivo y TOLERANTE: entradas malformadas se omiten
    // (el hilo no se cae por un adjunto raro del wire).
    final atts = <TrainerAttachmentDto>[];
    if (json['attachments'] is List<dynamic>) {
      for (final e in json['attachments'] as List<dynamic>) {
        if (e is! Map<String, dynamic>) continue;
        final att = TrainerAttachmentDto.tryParse(e);
        if (att != null) atts.add(att);
      }
    }
    // Campos de nota de voz: aditivos y DEFENSIVOS (tipo inesperado ⇒ vacío).
    String str(Object? v) => v is String ? v : '';
    return TrainerMessageDto(
      id: id,
      conversationId: conversationId,
      role: role,
      content: json['content'] is String ? json['content'] as String : '',
      toolCallsRaw: raw(json['tool_calls']),
      toolResultsRaw: raw(json['tool_results']),
      thinking: json['thinking'] is String ? json['thinking'] as String : '',
      attachments: atts,
      audioRef: str(json['audio_ref']),
      audioUrl: str(json['audio_url']),
      transcriptStatus: str(json['transcript_status']),
      transcript: str(json['transcript']),
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
  final List<TrainerAttachmentDto> attachments;
  final String audioRef;
  final String audioUrl;
  final String transcriptStatus;
  final String transcript;
  final DateTime createdAt;

  TrainerMessage toEntity() => TrainerMessage(
    id: id,
    conversationId: conversationId,
    role: role,
    content: content,
    toolCallsRaw: toolCallsRaw,
    toolResultsRaw: toolResultsRaw,
    thinking: thinking,
    attachments: attachments.map((a) => a.toEntity()).toList(growable: false),
    audioRef: audioRef,
    audioUrl: audioUrl,
    transcriptStatus: transcriptStatus,
    transcript: transcript,
    createdAt: createdAt,
  );
}

/// DTO de un adjunto del hilo (mismo shape en la subida y en el mensaje).
class TrainerAttachmentDto {
  const TrainerAttachmentDto({
    required this.ref,
    required this.mime,
    required this.name,
    required this.sizeBytes,
    this.url,
  });

  /// Canónico para la respuesta de la SUBIDA (shape garantizado).
  factory TrainerAttachmentDto.fromJson(Map<String, dynamic> json) {
    final att = tryParse(json);
    if (att == null) {
      throw const FormatException('trainer attachment: shape inválido');
    }
    return att;
  }

  /// Tolerante para las listas del hilo (malformado ⇒ null, se omite).
  static TrainerAttachmentDto? tryParse(Map<String, dynamic> json) {
    final ref = json['ref'];
    final mime = json['mime'];
    final name = json['name'];
    final size = json['sizeBytes'];
    if (ref is! String || mime is! String || name is! String || size is! num) {
      return null;
    }
    // La url firmada de preview es best-effort del wire: ausente, vacía o de
    // tipo inesperado degrada a null (el adjunto se conserva; sólo pierde la
    // fuente de respaldo).
    final url = json['url'];
    return TrainerAttachmentDto(
      ref: ref,
      mime: mime,
      name: name,
      sizeBytes: size.toInt(),
      url: url is String && url.isNotEmpty ? url : null,
    );
  }

  final String ref;
  final String mime;
  final String name;
  final int sizeBytes;
  final String? url;

  TrainerAttachment toEntity() => TrainerAttachment(
    ref: ref,
    mime: mime,
    name: name,
    sizeBytes: sizeBytes,
    url: url,
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
          // Flags de modalidad DEFENSIVOS: solo se adoptan si el wire los trae
          // como bool. Ausentes ⇒ null (desconocido) y la UI no muestra aviso.
          final img = e['imageInput'];
          final pdf = e['pdfInput'];
          options.add(
            TrainerModelOption(
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
