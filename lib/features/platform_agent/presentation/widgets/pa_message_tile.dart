import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/chat_bubble.dart';
import '../../domain/entities/pa_message.dart';

/// Renderiza un turno del hilo. user/assistant con texto ⇒ burbuja. Un turno
/// de assistant puro tool_calls (sin texto) ⇒ nada (la acción se cuenta con el
/// chip del tool). Un turno `tool` ⇒ chip compacto centrado "Usó {toolName}"
/// (v1 no expande el resultado crudo).
class PaMessageTile extends StatelessWidget {
  const PaMessageTile({required this.message, super.key});

  final PaMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isTool) {
      return _ToolChip(label: _toolLabel(message));
    }
    if (message.isAssistant && message.content.isEmpty) {
      return const SizedBox.shrink();
    }
    return ChatBubble(
      mine: message.isUser,
      child: Text(
        message.content,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppTokens.text1),
      ),
    );
  }

  /// Nombre de la tool del resultado (envelope `{toolName, content}`); vacío si
  /// el shape no es el esperado (el chip degrada a "Acción ejecutada").
  static String _toolLabel(PaMessage m) {
    final raw = m.toolResultsRaw;
    if (raw == null) return '';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['toolName'] is String) {
        return decoded['toolName'] as String;
      }
    } on FormatException {
      // content no-JSON: chip plano.
    }
    return '';
  }
}

/// Registro centrado de una acción ejecutada por el asistente (un tool). No es
/// burbuja de nadie: es un evento del hilo.
class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = label.isNotEmpty ? 'Usó $label' : 'Acción ejecutada';
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
          border: Border.all(color: AppTokens.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.bolt_outlined, size: 14, color: AppTokens.primary),
            const SizedBox(width: AppTokens.sp1),
            Flexible(
              child: Text(
                text,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppTokens.text1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
