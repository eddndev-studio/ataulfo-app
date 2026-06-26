import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/chat_bubble.dart';
import '../../../../core/design/widgets/message_timestamp.dart';
import '../../../../core/design/widgets/reasoning_disclosure.dart';
import '../../domain/entities/pa_message.dart';

/// Renderiza un turno del hilo. user/assistant con texto ⇒ burbuja. Un turno
/// de assistant puro tool_calls (sin texto) ⇒ nada (la acción se cuenta con la
/// tarjeta del tool). Un turno `tool` ⇒ tarjeta: chip compacto "Usó {toolName}"
/// que, si el resultado trae detalle estructurado (changeset o error), expande
/// a mostrarlo. Un resultado `requires_confirmation` con `onConfirm` cableado ⇒
/// tarjeta interactiva que nombra los bots afectados y ofrece Confirmar/Cancelar.
class PaMessageTile extends StatelessWidget {
  const PaMessageTile({required this.message, this.onConfirm, super.key});

  final PaMessage message;

  /// Acción al confirmar un requires_confirmation: la página reenvía una
  /// autorización por MessageSent (el LLM re-llama el tool con confirm=true).
  /// nil ⇒ la tarjeta de confirmación degrada a la de error genérica.
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    if (message.isTool) {
      final result = _ToolResult.parse(message.toolResultsRaw);
      if (result.requiresConfirmation && onConfirm != null) {
        return _ConfirmationCard(result: result, onConfirm: onConfirm!);
      }
      return _ExpandableToolCard(result: result);
    }
    if (message.isAssistant) {
      final hasThinking = message.thinking.isNotEmpty;
      if (message.content.isEmpty && !hasThinking) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (hasThinking)
            ReasoningDisclosure(reasoning: message.thinking, keyId: message.id),
          if (message.content.isNotEmpty)
            ChatBubble(
              mine: false,
              child: Text(
                message.content,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppTokens.text1),
              ),
            ),
          MessageTimestamp(at: message.createdAt),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ChatBubble(
          mine: message.isUser,
          child: Text(
            message.content,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTokens.text1),
          ),
        ),
        MessageTimestamp(at: message.createdAt),
      ],
    );
  }
}

/// Un campo que cambió en una escritura: ruta, valor previo y nuevo (ya como
/// texto legible). Espejo del `fieldChange` del backend.
class _FieldChange {
  const _FieldChange({required this.field, required this.from, required this.to});

  final String field;
  final String from;
  final String to;
}

/// Resultado de un tool, parseado del envelope `tool_results` del wire. El
/// envelope es jsonb crudo con claves snake_case (`tool_name`, `content`) y
/// `content` DOBLE-CODIFICADO: un string JSON con el output real del tool
/// (`{...summary, "changed":[...]}` en éxito, `{"error_kind":...}` en error).
class _ToolResult {
  const _ToolResult({
    required this.toolName,
    required this.changed,
    required this.errorKind,
    required this.bots,
  });

  final String toolName;
  final List<_FieldChange> changed;
  final String errorKind;

  /// Nombres de los Bots impactados, sólo poblado en requires_confirmation.
  final List<String> bots;

  /// Hay algo que valga la pena expandir (un changeset real o un error).
  bool get hasDetail => changed.isNotEmpty || errorKind.isNotEmpty;

  bool get requiresConfirmation => errorKind == 'requires_confirmation';

  static const _ToolResult _empty = _ToolResult(
    toolName: '',
    changed: <_FieldChange>[],
    errorKind: '',
    bots: <String>[],
  );

  static _ToolResult parse(String? raw) {
    if (raw == null || raw.isEmpty) return _empty;
    try {
      final outer = jsonDecode(raw);
      if (outer is! Map<String, dynamic>) return _empty;
      final toolName = outer['tool_name'] as String? ?? '';
      final inner = _innerContent(outer['content']);
      return _ToolResult(
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

  static List<_FieldChange> _parseChanged(Object? raw) {
    if (raw is! List) return const <_FieldChange>[];
    final out = <_FieldChange>[];
    for (final c in raw) {
      if (c is Map<String, dynamic>) {
        out.add(
          _FieldChange(
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
/// actuar, retira los botones para no permitir una doble confirmación. Es un
/// evento del hilo (centrado, no burbuja de nadie).
class _ConfirmationCard extends StatefulWidget {
  const _ConfirmationCard({required this.result, required this.onConfirm});

  final _ToolResult result;
  final VoidCallback onConfirm;

  @override
  State<_ConfirmationCard> createState() => _ConfirmationCardState();
}

class _ConfirmationCardState extends State<_ConfirmationCard> {
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
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
          padding: const EdgeInsets.all(AppTokens.sp3),
          decoration: BoxDecoration(
            color: AppTokens.surface2,
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            border: Border.all(color: AppTokens.divider),
          ),
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
        ),
      ),
    );
  }
}

/// Tarjeta de una acción ejecutada por el asistente. Colapsada es un chip
/// centrado "Usó {toolName}"; si el resultado trae detalle (changeset o error)
/// muestra un chevron y expande al tocarlo. Sin detalle, es un chip plano.
class _ExpandableToolCard extends StatefulWidget {
  const _ExpandableToolCard({required this.result});

  final _ToolResult result;

  @override
  State<_ExpandableToolCard> createState() => _ExpandableToolCardState();
}

class _ExpandableToolCardState extends State<_ExpandableToolCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final label = r.toolName.isNotEmpty ? 'Usó ${r.toolName}' : 'Acción ejecutada';

    if (!r.hasDetail) {
      return _ToolChip(label: label);
    }

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            InkWell(
              key: const Key('pa.tool_card.header'),
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              onTap: () => setState(() => _expanded = !_expanded),
              child: _ToolChip(
                label: label,
                trailing: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: AppTokens.text2,
                ),
                error: r.errorKind.isNotEmpty,
              ),
            ),
            if (_expanded) _ToolDetail(result: r),
          ],
        ),
      ),
    );
  }
}

/// Cuerpo expandido: el error (si lo hay) o el changeset campo a campo.
class _ToolDetail extends StatelessWidget {
  const _ToolDetail({required this.result});

  final _ToolResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    if (result.errorKind.isNotEmpty) {
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.warning_amber_rounded, size: 16, color: AppTokens.danger),
            const SizedBox(width: AppTokens.sp2),
            Expanded(
              child: Text(
                paToolErrorCopy(result.errorKind),
                key: const Key('pa.tool_card.error'),
                style: theme.textTheme.bodySmall?.copyWith(color: AppTokens.text1),
              ),
            ),
          ],
        ),
      );
    } else {
      for (final c in result.changed) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1 / 2),
            child: Text(
              '${c.field}: ${c.from} → ${c.to}',
              style: theme.textTheme.bodySmall?.copyWith(color: AppTokens.text1),
            ),
          ),
        );
      }
    }
    return Container(
      margin: const EdgeInsets.only(top: AppTokens.sp1),
      padding: const EdgeInsets.all(AppTokens.sp3),
      decoration: BoxDecoration(
        color: AppTokens.surface2,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: AppTokens.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Registro centrado de una acción ejecutada por el asistente. No es burbuja de
/// nadie: es un evento del hilo. `trailing` añade el chevron cuando la tarjeta
/// es expandible; `error` tiñe el borde cuando el resultado fue un fallo.
class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.label, this.trailing, this.error = false});

  final String label;
  final Widget? trailing;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp3,
          vertical: AppTokens.sp2,
        ),
        decoration: BoxDecoration(
          color: AppTokens.surface2,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(color: error ? AppTokens.danger : AppTokens.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              error ? Icons.error_outline : Icons.bolt_outlined,
              size: 14,
              color: error ? AppTokens.danger : AppTokens.primary,
            ),
            const SizedBox(width: AppTokens.sp1),
            Flexible(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppTokens.text1),
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: AppTokens.sp1),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
