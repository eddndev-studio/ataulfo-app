import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_thread_event_card.dart';
import '../../domain/entities/trainer_message.dart';

/// Un fallo de tool (error_kind) que antes se descartaba: ahora el operador lo
/// ve. `toolName` + el envelope error_kind, traducido a copy legible.
class TrainerToolErrorData {
  const TrainerToolErrorData({required this.toolName, required this.kind});

  final String toolName;
  final String kind;

  static TrainerToolErrorData? fromMessage(TrainerMessage m) {
    final raw = m.toolResultsRaw;
    if (raw == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final content = decoded['content'];
    if (content is! String) return null;
    Object? inner;
    try {
      inner = jsonDecode(content);
    } on FormatException {
      return null;
    }
    if (inner is! Map<String, dynamic>) return null;
    final kind = inner['error_kind'];
    if (kind is! String || kind.isEmpty) return null;
    return TrainerToolErrorData(
      toolName: decoded['toolName']?.toString() ?? '',
      kind: kind,
    );
  }
}

/// Traduce un error_kind del entrenador a copy en español para el operador.
String trainerToolErrorCopy(String kind) {
  switch (kind) {
    case 'anchor_not_found':
      return 'No encontré el ancla en el texto actual; vuelve a leerlo y reintenta.';
    case 'anchor_not_unique':
      return 'El ancla aparece varias veces; agrega contexto para que sea única.';
    case 'empty_anchor':
      return 'El ancla vacía solo aplica sobre contenido vacío (bootstrap).';
    case 'no_change':
      return 'El texto nuevo es igual al anterior: no hubo cambio.';
    case 'not_found':
      return 'No se encontró el recurso.';
    case 'already_exists':
      return 'Ya existe un recurso con ese nombre.';
    case 'invalid_input':
      return 'Dato inválido por las reglas del negocio.';
    case 'invalid_args':
      return 'Argumentos inválidos para la herramienta.';
    case 'version_conflict':
      return 'Conflicto de versión: algo cambió mientras editabas, reintenta.';
    case 'variable_in_use':
      return 'La variable está en uso por algún bot; limpia esos valores primero.';
    default:
      return 'La herramienta falló ($kind).';
  }
}

/// Tarjeta de error de un tool: registro centrado de un fallo (no una burbuja).
class TrainerToolErrorCard extends StatelessWidget {
  const TrainerToolErrorCard({
    super.key,
    required this.messageId,
    required this.data,
  });

  final String messageId;
  final TrainerToolErrorData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = data.toolName.isNotEmpty
        ? '${data.toolName}: ${trainerToolErrorCopy(data.kind)}'
        : trainerToolErrorCopy(data.kind);
    return AppThreadEventCard(
      key: Key('trainer.error_card.$messageId'),
      error: true,
      maxWidth: 520,
      child: AppThreadEventHeader(
        icon: Icons.warning_amber_rounded,
        label: label,
        error: true,
        crossAxisAlignment: CrossAxisAlignment.start,
        labelStyle: theme.textTheme.bodySmall?.copyWith(color: AppTokens.text1),
      ),
    );
  }
}
