import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_thread_event_card.dart';

/// Un campo que cambió en una escritura: ruta, valor previo y nuevo (ya como
/// texto legible). Espejo del `fieldChange` del backend.
class PaFieldChange {
  const PaFieldChange({
    required this.field,
    required this.from,
    required this.to,
  });

  final String field;
  final String from;
  final String to;
}

/// Resultado de un tool, parseado del envelope `tool_results` del wire. El
/// envelope es jsonb crudo con claves snake_case (`tool_name`, `content`) y
/// `content` DOBLE-CODIFICADO: un string JSON con el output real del tool
/// (`{...summary, "changed":[...]}` en éxito, `{"error_kind":...}` en error).
class PaToolResult {
  const PaToolResult({
    required this.toolName,
    required this.changed,
    required this.errorKind,
    required this.bots,
  });

  final String toolName;
  final List<PaFieldChange> changed;
  final String errorKind;

  /// Nombres de los Bots impactados, sólo poblado en requires_confirmation.
  final List<String> bots;

  /// Hay algo que valga la pena expandir (un changeset real o un error).
  bool get hasDetail => changed.isNotEmpty || errorKind.isNotEmpty;

  bool get requiresConfirmation => errorKind == 'requires_confirmation';

  static const PaToolResult _empty = PaToolResult(
    toolName: '',
    changed: <PaFieldChange>[],
    errorKind: '',
    bots: <String>[],
  );

  static PaToolResult parse(String? raw) {
    if (raw == null || raw.isEmpty) return _empty;
    try {
      final outer = jsonDecode(raw);
      if (outer is! Map<String, dynamic>) return _empty;
      final toolName = outer['tool_name'] as String? ?? '';
      final inner = _innerContent(outer['content']);
      return PaToolResult(
        toolName: toolName,
        changed: _parseChanged(inner['changed']),
        errorKind: inner['error_kind'] as String? ?? '',
        bots: _parseBots(inner['bots']),
      );
    } on FormatException {
      // tool_results no es JSON: degrada a chip sin nombre.
      return _empty;
    }
  }

  static List<String> _parseBots(Object? raw) {
    if (raw is! List) return const <String>[];
    final out = <String>[];
    for (final b in raw) {
      if (b is Map<String, dynamic>) {
        final name = b['name']?.toString() ?? '';
        if (name.isNotEmpty) out.add(name);
      }
    }
    return out;
  }

  /// `content` normalmente es un string JSON (doble-codificado); se tolera que
  /// algún día llegue como objeto. Cualquier otra cosa ⇒ mapa vacío.
  static Map<String, dynamic> _innerContent(Object? content) {
    if (content is Map<String, dynamic>) return content;
    if (content is String && content.isNotEmpty) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) return decoded;
      } on FormatException {
        // content no-JSON (p. ej. un `{"status":"reacted"}` plano o texto):
        // sin detalle estructurado.
      }
    }
    return <String, dynamic>{};
  }

  static List<PaFieldChange> _parseChanged(Object? raw) {
    if (raw is! List) return const <PaFieldChange>[];
    final out = <PaFieldChange>[];
    for (final c in raw) {
      if (c is Map<String, dynamic>) {
        out.add(
          PaFieldChange(
            field: c['field']?.toString() ?? '',
            from: _fmt(c['from']),
            to: _fmt(c['to']),
          ),
        );
      }
    }
    return out;
  }

  /// Valor de un campo a texto: null ⇒ '∅' (distingue "vacío" de la cadena
  /// "null"); el resto, su representación natural.
  static String _fmt(Object? v) => v == null ? '∅' : v.toString();
}

/// Traduce un `error_kind` del backend a copy en español para el operador.
String paToolErrorCopy(String kind) {
  switch (kind) {
    case 'not_found':
      return 'No se encontró el recurso.';
    case 'version_conflict':
      return 'Conflicto de versión: alguien más lo cambió, reintenta.';
    case 'invalid_input':
      return 'Dato inválido por las reglas del negocio.';
    case 'invalid_args':
      return 'Argumentos inválidos para la herramienta.';
    case 'forbidden_for_role':
      return 'Tu rol no tiene permiso para esta acción.';
    case 'variable_in_use':
      return 'La variable está en uso por algún bot.';
    case 'requires_confirmation':
      return 'Requiere confirmación antes de aplicar.';
    case 'unknown_tool':
      return 'Herramienta desconocida.';
    case 'builtin_error':
      return 'La herramienta falló.';
    default:
      return 'Error: $kind';
  }
}

/// Tarjeta interactiva de un requires_confirmation: nombra los Bots impactados y
/// ofrece Confirmar/Cancelar. Confirmar dispara onConfirm (la página reenvía la
/// autorización al asistente, que re-llama el tool con confirm=true) y, tras
/// actuar, retira los botones para no permitir una doble confirmación.
class PaConfirmationCard extends StatefulWidget {
  const PaConfirmationCard({
    super.key,
    required this.result,
    required this.onConfirm,
  });

  final PaToolResult result;
  final VoidCallback onConfirm;

  @override
  State<PaConfirmationCard> createState() => _PaConfirmationCardState();
}

class _PaConfirmationCardState extends State<PaConfirmationCard> {
  // null = pendiente; true = confirmado; false = cancelado.
  bool? _decision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bots = widget.result.bots;
    final n = bots.length;
    final lead = n > 0
        ? 'Esta acción afecta a $n bot${n == 1 ? '' : 's'}: ${bots.join(', ')}.'
        : 'Esta acción requiere tu confirmación.';
    return AppThreadEventCard(
      maxWidth: 520,
      fill: true,
      padding: const EdgeInsets.all(AppTokens.sp3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.help_outline,
                size: 16,
                color: AppTokens.primary,
              ),
              const SizedBox(width: AppTokens.sp2),
              Expanded(
                child: Text(
                  lead,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTokens.text1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.sp2),
          if (_decision == null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                AppButton.text(
                  key: const Key('pa.confirm.cancel'),
                  label: 'Cancelar',
                  onPressed: () => setState(() => _decision = false),
                ),
                const SizedBox(width: AppTokens.sp2),
                AppButton.filled(
                  key: const Key('pa.confirm.accept'),
                  label: 'Confirmar',
                  onPressed: () {
                    widget.onConfirm();
                    setState(() => _decision = true);
                  },
                ),
              ],
            )
          else
            Text(
              _decision! ? 'Confirmado.' : 'Cancelado.',
              key: const Key('pa.confirm.outcome'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTokens.text2,
              ),
            ),
        ],
      ),
    );
  }
}

/// Tarjeta de una acción ejecutada por el asistente. Colapsada es un chip
/// centrado "Usó {toolName}"; si el resultado trae detalle (changeset o error)
/// muestra un chevron y expande al tocarlo dentro de la misma tarjeta. Sin
/// detalle, es un chip plano.
class PaExpandableToolCard extends StatefulWidget {
  const PaExpandableToolCard({super.key, required this.result});

  final PaToolResult result;

  @override
  State<PaExpandableToolCard> createState() => _PaExpandableToolCardState();
}

class _PaExpandableToolCardState extends State<PaExpandableToolCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final label = r.toolName.isNotEmpty
        ? 'Usó ${r.toolName}'
        : 'Acción ejecutada';
    final isError = r.errorKind.isNotEmpty;

    if (!r.hasDetail) {
      return AppThreadEventCard(
        child: AppThreadEventHeader(icon: Icons.bolt_outlined, label: label),
      );
    }

    return AppThreadEventCard(
      key: const Key('pa.tool_card.header'),
      maxWidth: 520,
      error: isError,
      expanded: _expanded,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppThreadEventHeader(
            icon: isError ? Icons.error_outline : Icons.bolt_outlined,
            label: label,
            error: isError,
            showChevron: true,
            expanded: _expanded,
          ),
          if (_expanded) ...<Widget>[
            const SizedBox(height: AppTokens.sp2),
            _ToolDetail(result: r),
          ],
        ],
      ),
    );
  }
}

/// Cuerpo expandido de una tarjeta de tool: el error (si lo hay) o el changeset
/// campo a campo. Vive DENTRO de la tarjeta (la caja compartida ya aporta la
/// superficie y el borde), no como una caja aparte.
class _ToolDetail extends StatelessWidget {
  const _ToolDetail({required this.result});

  final PaToolResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (result.errorKind.isNotEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppTokens.danger,
          ),
          const SizedBox(width: AppTokens.sp2),
          Expanded(
            child: Text(
              paToolErrorCopy(result.errorKind),
              key: const Key('pa.tool_card.error'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTokens.text1,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final c in result.changed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1 / 2),
            child: Text(
              '${c.field}: ${c.from} → ${c.to}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTokens.text1,
              ),
            ),
          ),
      ],
    );
  }
}
