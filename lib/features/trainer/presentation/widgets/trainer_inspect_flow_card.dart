import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_thread_event_card.dart';
import '../../domain/entities/trainer_message.dart';

/// Un paso del flujo, proyectado para la tarjeta de inspección.
class TrainerInspectStep {
  const TrainerInspectStep({
    required this.type,
    required this.content,
    required this.mediaRef,
  });

  final String type;
  final String content;
  final String mediaRef;

  /// Resumen legible: el contenido (texto) o, si es multimedia, su ref.
  String get summary => content.isNotEmpty ? content : mediaRef;
}

/// Resultado de inspect_flow proyectado a la tarjeta: nombre del flujo + sus
/// pasos en orden y los disparadores que lo activan. El envelope del wire del
/// entrenador es camelCase ({toolName, content}); content es un STRING JSON
/// doble-codificado con la estructura del flujo (claves snake_case).
class TrainerInspectFlowData {
  const TrainerInspectFlowData({
    required this.name,
    required this.isActive,
    required this.steps,
    required this.triggers,
  });

  final String name;
  final bool isActive;
  final List<TrainerInspectStep> steps;
  final List<String> triggers;

  static TrainerInspectFlowData? fromMessage(TrainerMessage m) {
    final raw = m.toolResultsRaw;
    if (raw == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['toolName'] != 'inspect_flow') return null;
    final content = decoded['content'];
    if (content is! String) return null;
    Object? inner;
    try {
      inner = jsonDecode(content);
    } on FormatException {
      return null;
    }
    if (inner is! Map<String, dynamic>) return null;
    if (inner.containsKey('error_kind')) {
      return null; // un error no es inspección
    }

    final steps = <TrainerInspectStep>[];
    final rawSteps = inner['steps'];
    if (rawSteps is List) {
      for (final s in rawSteps) {
        if (s is Map<String, dynamic>) {
          steps.add(
            TrainerInspectStep(
              type: s['type']?.toString() ?? '',
              content: s['content']?.toString() ?? '',
              mediaRef: s['media_ref']?.toString() ?? '',
            ),
          );
        }
      }
    }
    final triggers = <String>[];
    final rawTriggers = inner['triggers'];
    if (rawTriggers is List) {
      for (final tr in rawTriggers) {
        if (tr is Map<String, dynamic>) {
          triggers.add(_triggerLabel(tr));
        }
      }
    }
    return TrainerInspectFlowData(
      name: inner['name']?.toString() ?? 'Flujo',
      isActive: inner['is_active'] == true,
      steps: steps,
      triggers: triggers,
    );
  }

  static String _triggerLabel(Map<String, dynamic> tr) {
    final type = tr['trigger_type']?.toString() ?? '';
    if (type == 'TEXT') {
      return "TEXT '${tr['keyword']?.toString() ?? ''}'";
    }
    if (type == 'LABEL') {
      return 'LABEL ${tr['label_action']?.toString() ?? ''}';
    }
    return type;
  }
}

/// Ícono por tipo de paso (para la tarjeta de inspección).
IconData _stepTypeIcon(String type) => switch (type) {
  'TEXT' => Icons.short_text,
  'IMAGE' => Icons.image_outlined,
  'VIDEO' => Icons.videocam_outlined,
  'DOCUMENT' => Icons.description_outlined,
  'AUDIO' || 'PTT' => Icons.audiotrack_outlined,
  'STICKER' => Icons.emoji_emotions_outlined,
  'LABEL' => Icons.label_outline,
  'CONDITIONAL_TIME' => Icons.schedule_outlined,
  'END' => Icons.stop_circle_outlined,
  _ => Icons.circle_outlined,
};

/// Tarjeta de inspección de un flujo (resultado de inspect_flow): el entrenador
/// ve la estructura sin abrir el editor. Colapsada muestra el nombre + conteos;
/// al tocarla expande los pasos (con su ícono de tipo) y los disparadores.
class TrainerInspectFlowCard extends StatefulWidget {
  const TrainerInspectFlowCard({
    super.key,
    required this.messageId,
    required this.data,
  });

  final String messageId;
  final TrainerInspectFlowData data;

  @override
  State<TrainerInspectFlowCard> createState() => _TrainerInspectFlowCardState();
}

class _TrainerInspectFlowCardState extends State<TrainerInspectFlowCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final theme = Theme.of(context);
    final header = AppThreadEventHeader(
      icon: Icons.account_tree_outlined,
      label: 'Flujo: ${data.name}',
      showChevron: true,
      expanded: _expanded,
      chevronKey: Key('trainer.inspect_card.${widget.messageId}.expand'),
    );
    return AppThreadEventCard(
      key: Key('trainer.inspect_card.${widget.messageId}'),
      expanded: _expanded,
      onTap: () => setState(() => _expanded = !_expanded),
      child: _expanded
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                header,
                const SizedBox(height: AppTokens.sp2),
                _InspectFlowDetail(data: data),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                header,
                Padding(
                  padding: const EdgeInsets.only(top: AppTokens.sp1),
                  child: Text(
                    '${data.steps.length} pasos · ${data.triggers.length} disparadores',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTokens.text2,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InspectFlowDetail extends StatelessWidget {
  const _InspectFlowDetail({required this.data});

  final TrainerInspectFlowData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(color: AppTokens.text1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < data.steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1 / 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  _stepTypeIcon(data.steps[i].type),
                  size: 14,
                  color: AppTokens.text2,
                ),
                const SizedBox(width: AppTokens.sp2),
                Expanded(
                  child: Text(
                    '${i + 1}. ${data.steps[i].summary}',
                    style: small,
                  ),
                ),
              ],
            ),
          ),
        if (data.triggers.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppTokens.sp2),
          Text(
            'Disparadores',
            style: theme.textTheme.labelSmall?.copyWith(color: AppTokens.text2),
          ),
          for (final t in data.triggers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1 / 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.bolt_outlined,
                    size: 14,
                    color: AppTokens.text2,
                  ),
                  const SizedBox(width: AppTokens.sp2),
                  Flexible(child: Text(t, style: small)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
