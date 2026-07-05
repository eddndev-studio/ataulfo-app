import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_thread_event_card.dart';
import '../../../../core/design/widgets/message_timestamp.dart';
import '../../domain/entities/trainer_message.dart';

/// Una versión archivada del prompt: id (para pedir restaurar), preview y cuándo.
class TrainerPromptVersionItem {
  const TrainerPromptVersionItem({
    required this.id,
    required this.preview,
    required this.createdAt,
  });

  final int id;
  final String preview;
  final DateTime createdAt;
}

/// Resultado de list_prompt_history: el historial de versiones del prompt para
/// que el operador vea qué hubo antes y pida restaurar una por su id.
class TrainerPromptHistoryData {
  const TrainerPromptHistoryData({required this.versions});

  final List<TrainerPromptVersionItem> versions;

  static TrainerPromptHistoryData? fromMessage(TrainerMessage m) {
    final raw = m.toolResultsRaw;
    if (raw == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['toolName'] != 'list_prompt_history') return null;
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
      return null; // un fallo no es historial
    }
    final out = <TrainerPromptVersionItem>[];
    final rawV = inner['versions'];
    if (rawV is List) {
      for (final v in rawV) {
        if (v is Map<String, dynamic>) {
          out.add(
            TrainerPromptVersionItem(
              id: (v['id'] as num?)?.toInt() ?? 0,
              preview: v['preview']?.toString() ?? '',
              createdAt:
                  DateTime.tryParse(v['created_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            ),
          );
        }
      }
    }
    return TrainerPromptHistoryData(versions: out);
  }
}

/// Tarjeta colapsable del historial del prompt: lista las versiones previas con
/// su id, preview y cuándo. La restauración la pide el operador por chat (el
/// agente llama a restore_prompt_version, que confirma antes de pisar el prompt).
class TrainerPromptHistoryCard extends StatefulWidget {
  const TrainerPromptHistoryCard({
    super.key,
    required this.messageId,
    required this.data,
  });

  final String messageId;
  final TrainerPromptHistoryData data;

  @override
  State<TrainerPromptHistoryCard> createState() =>
      _TrainerPromptHistoryCardState();
}

class _TrainerPromptHistoryCardState extends State<TrainerPromptHistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final versions = widget.data.versions;
    final header = AppThreadEventHeader(
      icon: Icons.history_outlined,
      label: versions.isEmpty
          ? 'Historial del prompt: sin versiones'
          : 'Historial del prompt (${versions.length})',
      showChevron: versions.isNotEmpty,
      expanded: _expanded,
      chevronKey: Key('trainer.prompt_history_card.${widget.messageId}.expand'),
    );
    return AppThreadEventCard(
      key: Key('trainer.prompt_history_card.${widget.messageId}'),
      expanded: _expanded,
      onTap: versions.isEmpty
          ? null
          : () => setState(() => _expanded = !_expanded),
      child: _expanded
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                header,
                const SizedBox(height: AppTokens.sp2),
                for (final v in versions) _PromptVersionRow(item: v),
                const SizedBox(height: AppTokens.sp1),
                Text(
                  'Pídeme restaurar una versión por su id.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTokens.text2,
                  ),
                ),
              ],
            )
          : header,
    );
  }
}

class _PromptVersionRow extends StatelessWidget {
  const _PromptVersionRow({required this.item});

  final TrainerPromptVersionItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.sp2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Versión #${item.id}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTokens.text1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppTokens.sp2),
              MessageTimestamp(at: item.createdAt),
            ],
          ),
          if (item.preview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.sp1),
              child: Text(
                item.preview,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTokens.text2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
