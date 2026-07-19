import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_disclosure_tile.dart';
import '../../../../core/design/widgets/assistant_markdown.dart';
import '../../../../core/design/widgets/chat_bubble.dart';
import '../../../../core/design/widgets/reasoning_disclosure.dart';
import '../../domain/entities/ai_log_entry.dart';
import 'tool_result_view.dart';

/// Render PLANO de un turno del ConversationLog — el idioma original del
/// ai-log, hoy reservado a la historia legacy («Actividad previa», filas sin
/// run_id) donde no se inventa agrupación por corrida.
class AiLogEntryTile extends StatelessWidget {
  const AiLogEntryTile({super.key, required this.entry});

  final AiLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.sp3),
      child: switch (entry.role) {
        // El cliente es el emisor "local" de esta vista: su turno va a la
        // derecha, como en el hilo real. Su texto es transcripción verbatim
        // de WhatsApp — nunca se reinterpreta como Markdown.
        AiLogRole.user => AiLogTurnBubble(
          icon: Icons.person_outline,
          title: 'Cliente',
          mine: true,
          child: Text(entry.content, style: textTheme.bodyMedium),
        ),
        AiLogRole.assistant => _AssistantTurn(entry: entry),
        AiLogRole.tool => ToolResultView(entry: entry),
        // La voz del MOTOR (p.ej. el nudge de disciplina): rotulada Sistema y
        // atenuada, para que el operador no la lea como palabras del cliente.
        AiLogRole.system => AiLogTurnBubble(
          icon: Icons.settings_outlined,
          title: 'Sistema',
          mine: false,
          child: Text(
            entry.content,
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
        ),
        AiLogRole.unknown => Text(
          'Turno no soportado — actualiza la app.',
          style: textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: AppTokens.text2,
          ),
        ),
      },
    );
  }
}

/// Turno simple (user/system/respuesta del bot): caption de rol sobre la
/// [ChatBubble] canónica, apilados del lado del emisor.
class AiLogTurnBubble extends StatelessWidget {
  const AiLogTurnBubble({
    super.key,
    required this.icon,
    required this.title,
    required this.mine,
    required this.child,
  });

  final IconData icon;
  final String title;
  final bool mine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AiLogRoleCaption(icon: icon, title: title),
        ChatBubble(mine: mine, child: child),
      ],
    );
  }
}

/// Turno del bot: caption + razonamiento colapsable del kit + la respuesta en
/// burbuja Markdown (los agentes emiten CommonMark) + una tarjeta expandible
/// por llamada a tool. Un turno puro tool_calls no pinta burbuja vacía.
class _AssistantTurn extends StatelessWidget {
  const _AssistantTurn({required this.entry});

  final AiLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const AiLogRoleCaption(
          icon: Icons.smart_toy_outlined,
          title: 'Asistente',
        ),
        if (entry.reasoning.isNotEmpty)
          ReasoningDisclosure(reasoning: entry.reasoning, keyId: '${entry.id}'),
        if (entry.content.isNotEmpty)
          ChatBubble(
            mine: false,
            child: AssistantMarkdown(data: entry.content),
          ),
        for (final tc in entry.toolCalls) AiLogToolCallTile(call: tc),
      ],
    );
  }
}

/// Caption de rol sobre la burbuja: quién habla en este turno.
class AiLogRoleCaption extends StatelessWidget {
  const AiLogRoleCaption({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: AppTokens.text2),
        const SizedBox(width: AppTokens.sp1),
        Text(
          title,
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
      ],
    );
  }
}

/// Llamada a una tool: el nombre a la vista y los argumentos JSON expandibles
/// al tocar — el mismo patrón que el resultado un renglón abajo. (Un tooltip
/// de hover sería inaccesible en táctil.)
class AiLogToolCallTile extends StatelessWidget {
  const AiLogToolCallTile({super.key, required this.call});

  final AiToolCall call;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.sp2),
      child: AppDisclosureTile(
        key: Key('ai_log.tool_call.${call.id}'),
        icon: Icons.bolt_outlined,
        title: call.name,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            call.argumentsJson.isEmpty
                ? '(sin argumentos)'
                : call.argumentsJson,
            style: textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: AppTokens.text2,
            ),
          ),
        ),
      ),
    );
  }
}
