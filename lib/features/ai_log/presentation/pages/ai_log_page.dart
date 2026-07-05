import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_disclosure_tile.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/assistant_markdown.dart';
import '../../../../core/design/widgets/chat_bubble.dart';
import '../../../../core/design/widgets/reasoning_disclosure.dart';
import '../../domain/ai_log_runs.dart';
import '../../domain/entities/ai_log_entry.dart';
import '../../domain/failures/ai_log_failure.dart';
import '../ai_log_format.dart';
import '../bloc/ai_log_bloc.dart';
import '../widgets/tool_result_view.dart';

/// Vista de observabilidad del bot (ADMIN+): el ConversationLog del chat
/// real dividido POR CORRIDA del motor — qué dijo el cliente, qué pensó el
/// modelo (razonamiento colapsable), qué herramientas llamó y con qué
/// resultado, y cuántos tokens costó. Es la versión para producción del
/// transcript de "Probar bot".
class AiLogPage extends StatelessWidget {
  const AiLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiLogBloc, AiLogState>(
      builder: (context, state) => switch (state) {
        AiLogLoading() => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
          ),
        ),
        AiLogFailed(failure: final f) => _FailedView(failure: f),
        AiLogLoaded() => _LogView(state: state),
      },
    );
  }
}

class _LogView extends StatelessWidget {
  const _LogView({required this.state});

  final AiLogLoaded state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (state.entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.sp6),
          child: Text(
            'Este chat aún no tiene actividad del bot de IA.',
            key: const Key('ai_log.empty'),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
        ),
      );
    }
    final runs = groupIntoRuns(state.entries);
    return ListView(
      padding: const EdgeInsets.all(AppTokens.sp4),
      children: <Widget>[
        for (final run in runs) ...<Widget>[
          _RunCard(run: run),
          const SizedBox(height: AppTokens.sp3),
        ],
        if (state.nextBefore != null)
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.sp2),
            child: AppButton.tonal(
              key: const Key('ai_log.load_more'),
              label: state.isLoadingMore ? 'Cargando…' : 'Cargar anteriores',
              onPressed: state.isLoadingMore
                  ? null
                  : () => context.read<AiLogBloc>().add(
                      const AiLogMoreRequested(),
                    ),
              fullWidth: true,
            ),
          ),
      ],
    );
  }
}

/// Una corrida del motor: header con modelo/tokens/hora + los turnos en
/// orden cronológico.
class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});

  final AiLogRun run;

  /// Porcentaje redondeado del prompt servido desde caché; 0 sin caché (o con
  /// una proporción que redondea a cero, que el header omite).
  int get _cachePct => run.promptTokens > 0
      ? (run.cachedTokens * 100 / run.promptTokens).round().clamp(0, 100)
      : 0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final t = run.startedAt.toLocal();
    final stamp =
        '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return AppCard(
      padding: AppTokens.sp4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppTokens.sp2,
            runSpacing: AppTokens.sp1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                stamp,
                style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
              ),
              if (run.model.isNotEmpty) AppPill.outline(label: run.model),
              // Tokens de entrada al modelo (prompt) y generados (completion),
              // abreviados; las flechas comunican la dirección sin texto extra.
              if (run.promptTokens > 0)
                AppPill.neutral(
                  icon: Icons.arrow_upward,
                  label: formatTokensCompact(run.promptTokens),
                ),
              if (run.completionTokens > 0)
                AppPill.neutral(
                  icon: Icons.arrow_downward,
                  label: formatTokensCompact(run.completionTokens),
                ),
              // Proporción del prompt servida desde caché (más barata). Una
              // proporción real que redondea a 0% se omite: "caché 0%" leería
              // como sin-caché.
              if (_cachePct > 0) AppPill.neutral(label: 'caché $_cachePct%'),
              if (run.costMicroUsd > 0)
                AppPill.outline(label: formatMicroUsd(run.costMicroUsd)),
              // Corridas viejas sin desglose prompt/completion: se conserva el
              // pill único de total para no perder el dato.
              if (run.promptTokens == 0 &&
                  run.completionTokens == 0 &&
                  run.totalTokens > 0)
                AppPill.neutral(label: '${run.totalTokens} tokens'),
            ],
          ),
          const SizedBox(height: AppTokens.sp3),
          for (final e in run.entries) _EntryTile(entry: e),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

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
        AiLogRole.user => _Turn(
          icon: Icons.person_outline,
          title: 'Cliente',
          mine: true,
          child: Text(entry.content, style: textTheme.bodyMedium),
        ),
        AiLogRole.assistant => _AssistantTurn(entry: entry),
        AiLogRole.tool => ToolResultView(entry: entry),
        // La voz del MOTOR (p.ej. el nudge de disciplina): rotulada Sistema y
        // atenuada, para que el operador no la lea como palabras del cliente.
        AiLogRole.system => _Turn(
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

/// Turno simple (user/system): caption de rol sobre la [ChatBubble] canónica,
/// apilados del lado del emisor.
class _Turn extends StatelessWidget {
  const _Turn({
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
        _RoleCaption(icon: icon, title: title),
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
        const _RoleCaption(icon: Icons.smart_toy_outlined, title: 'Bot'),
        if (entry.reasoning.isNotEmpty)
          ReasoningDisclosure(reasoning: entry.reasoning, keyId: '${entry.id}'),
        if (entry.content.isNotEmpty)
          ChatBubble(
            mine: false,
            child: AssistantMarkdown(data: entry.content),
          ),
        for (final tc in entry.toolCalls) _ToolCallTile(call: tc),
      ],
    );
  }
}

/// Caption de rol sobre la burbuja: quién habla en este turno.
class _RoleCaption extends StatelessWidget {
  const _RoleCaption({required this.icon, required this.title});

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

/// Llamada a una tool del turno assistant: el nombre a la vista y los
/// argumentos JSON expandibles al tocar — el mismo patrón que el resultado un
/// renglón abajo. (Un tooltip de hover sería inaccesible en táctil.)
class _ToolCallTile extends StatelessWidget {
  const _ToolCallTile({required this.call});

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

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final AiLogFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final copy = switch (failure) {
      AiLogForbiddenFailure() =>
        'Tu rol no permite ver el razonamiento del bot. Pide acceso a un admin.',
      AiLogNetworkFailure() =>
        'Sin conexión con el servidor. Revisa tu red y reintenta.',
      AiLogUnknownFailure() =>
        'No pudimos cargar el registro del bot. Inténtalo de nuevo.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(copy, textAlign: TextAlign.center, style: textTheme.bodyLarge),
            if (failure is! AiLogForbiddenFailure) ...<Widget>[
              const SizedBox(height: AppTokens.sp3),
              AppButton.tonal(
                label: 'Reintentar',
                onPressed: () =>
                    context.read<AiLogBloc>().add(const AiLogLoadRequested()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
