import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/tool_glyphs.dart';
import '../../../../core/design/widgets/app_thread_event_card.dart';
import '../../domain/entities/trainer_message.dart';

/// Diff embebido en el envelope de una tool de escritura (puede faltar:
/// historial previo al server que lo computa — la tarjeta degrada).
class TrainerChangeDiff {
  const TrainerChangeDiff({required this.oldStr, required this.newStr});

  final String oldStr;
  final String newStr;
}

/// Datos de una tarjeta de cambio: proyección de un tool result de escritura.
/// Las lecturas (overview/read_*/list_*/done) no rinden tarjeta. `name`/`diff`
/// salen del envelope ANIDADO (content es un string JSON) y alimentan la vista
/// expandida; sin detalle, la tarjeta es plana.
class TrainerChangeCardData {
  const TrainerChangeCardData({
    required this.icon,
    required this.title,
    this.name,
    this.diff,
  });

  final IconData icon;
  final String title;
  final String? name;
  final TrainerChangeDiff? diff;

  bool get expandable => name != null || diff != null;

  static TrainerChangeCardData? fromMessage(TrainerMessage m) {
    final raw = m.toolResultsRaw;
    if (raw == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final rawTool = decoded['toolName'];
    final tool = rawTool is String ? rawTool : '';
    final content = decoded['content'];
    final failed = content is String && content.contains('"error_kind"');
    if (failed) return null; // los envelopes de error no son cambios

    // El envelope de la tool viaja como STRING JSON dentro de content.
    String? name;
    TrainerChangeDiff? diff;
    if (content is String) {
      try {
        final env = jsonDecode(content);
        if (env is Map<String, dynamic>) {
          if (env['name'] is String) name = env['name'] as String;
          final d = env['diff'];
          if (d is Map<String, dynamic> &&
              (d['old'] is String || d['new'] is String)) {
            diff = TrainerChangeDiff(
              oldStr: d['old'] is String ? d['old'] as String : '',
              newStr: d['new'] is String ? d['new'] as String : '',
            );
          }
        }
      } on FormatException {
        // Content no-JSON: la tarjeta queda plana.
      }
    }
    // Título e ícono salen del mapa central (tool_glyphs): la tarjeta y el
    // nodo de la traza deben leer idéntico. Solo el diff distingue a las
    // escrituras con texto (prompt/docs) de las de archivos (solo nombre).
    return switch (tool) {
      'edit_prompt' || 'write_doc' || 'edit_doc' => TrainerChangeCardData(
        icon: toolIconFor(tool),
        title: toolTitleFor(tool),
        name: name,
        diff: diff,
      ),
      'delete_doc' ||
      'save_file' ||
      'update_file_meta' ||
      'delete_file' => TrainerChangeCardData(
        icon: toolIconFor(tool),
        title: toolTitleFor(tool),
        name: name,
      ),
      _ => null,
    };
  }
}

/// Tarjeta de cambio: registro de que el entrenador escribió en el workspace.
/// Centrada como los chips de acción del preview — es un evento del hilo, no
/// una burbuja de nadie. Con detalle (nombre/diff) se expande al tocarla; el
/// estado vive en el widget (efímero, como el resto del transcript).
class TrainerChangeCard extends StatefulWidget {
  const TrainerChangeCard({
    super.key,
    required this.messageId,
    required this.data,
  });

  final String messageId;
  final TrainerChangeCardData data;

  @override
  State<TrainerChangeCard> createState() => _TrainerChangeCardState();
}

class _TrainerChangeCardState extends State<TrainerChangeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final header = AppThreadEventHeader(
      icon: data.icon,
      label: data.title,
      showChevron: data.expandable,
      expanded: _expanded,
      chevronKey: Key('trainer.change_card.${widget.messageId}.expand'),
    );
    return AppThreadEventCard(
      key: Key('trainer.change_card.${widget.messageId}'),
      expanded: _expanded,
      onTap: data.expandable
          ? () => setState(() => _expanded = !_expanded)
          : null,
      child: _expanded
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                header,
                const SizedBox(height: AppTokens.sp2),
                _ChangeDetail(data: data),
              ],
            )
          : header,
    );
  }
}

/// Cuerpo expandido: nombre del recurso + bloques del diff (lo reemplazado
/// y lo nuevo). Monospace para que el operador lea el texto literal.
class _ChangeDetail extends StatelessWidget {
  const _ChangeDetail({required this.data});

  final TrainerChangeCardData data;

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppTokens.text1,
      fontFamily: 'monospace',
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (data.name != null)
          Text(
            data.name!,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppTokens.text2),
          ),
        if (data.diff != null) ...<Widget>[
          if (data.diff!.oldStr.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppTokens.sp2),
            _diffBlock(
              data.diff!.oldStr,
              AppTokens.danger,
              mono?.copyWith(decoration: TextDecoration.lineThrough),
            ),
          ],
          if (data.diff!.newStr.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppTokens.sp1),
            _diffBlock(data.diff!.newStr, AppTokens.success, mono),
          ],
        ],
      ],
    );
  }

  Widget _diffBlock(String text, Color accent, TextStyle? style) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.sp2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border(left: BorderSide(color: accent, width: 2)),
      ),
      child: Text(text, style: style),
    );
  }
}
