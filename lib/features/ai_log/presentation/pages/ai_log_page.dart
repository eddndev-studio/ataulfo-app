import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/ai_log_runs.dart';
import '../../domain/entities/ai_log_entry.dart';
import '../../domain/failures/ai_log_failure.dart';
import '../bloc/ai_log_bloc.dart';

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
              if (run.totalTokens > 0)
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
        AiLogRole.user => _bubble(
          context,
          icon: Icons.person_outline,
          title: 'Cliente',
          child: Text(entry.content, style: textTheme.bodyMedium),
        ),
        AiLogRole.assistant => _bubble(
          context,
          icon: Icons.smart_toy_outlined,
          title: 'Bot',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (entry.reasoning.isNotEmpty)
                _Reasoning(reasoning: entry.reasoning, entryId: entry.id),
              if (entry.content.isNotEmpty)
                Text(entry.content, style: textTheme.bodyMedium),
              if (entry.toolCalls.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppTokens.sp2),
                  child: Wrap(
                    spacing: AppTokens.sp2,
                    runSpacing: AppTokens.sp1,
                    children: <Widget>[
                      for (final tc in entry.toolCalls)
                        Tooltip(
                          message: tc.argumentsJson.isEmpty
                              ? tc.name
                              : tc.argumentsJson,
                          child: AppPill.primary(label: '⚙ ${tc.name}'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        AiLogRole.tool => _ToolResult(entry: entry),
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

  Widget _bubble(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: AppTokens.text2),
        const SizedBox(width: AppTokens.sp2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
              ),
              const SizedBox(height: AppTokens.sp1),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

/// Razonamiento colapsable: cerrado por default (es detalle de
/// diagnóstico), expandible por turno.
class _Reasoning extends StatelessWidget {
  const _Reasoning({required this.reasoning, required this.entryId});

  final String reasoning;
  final int entryId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.sp2),
      // El fondo lo da un Material (no un DecoratedBox con color): el ListTile
      // interno del ExpansionTile pinta su superficie/tinte sobre el Material
      // ancestro más cercano; un color en un DecoratedBox intermedio lo taparía.
      child: Material(
        color: AppTokens.surface2,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: Key('ai_log.reasoning.$entryId'),
            tilePadding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppTokens.sp3,
              0,
              AppTokens.sp3,
              AppTokens.sp3,
            ),
            leading: const Icon(
              Icons.psychology_outlined,
              size: 18,
              color: AppTokens.text2,
            ),
            title: Text(
              'Razonamiento',
              style: textTheme.labelMedium?.copyWith(color: AppTokens.text2),
            ),
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  reasoning,
                  style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resultado de una tool: colapsado a una línea, expandible al contenido
/// completo que el modelo recibió.
class _ToolResult extends StatelessWidget {
  const _ToolResult({required this.entry});

  final AiLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      // Borde sin relleno vía `shape`; al ser un Material, el ListTile del
      // ExpansionTile encuentra superficie aquí y no hereda el fondo coloreado
      // de la AppCard contenedora (que dispararía el assert de Material 3).
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppTokens.divider),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: Key('ai_log.tool_result.${entry.id}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppTokens.sp3,
            0,
            AppTokens.sp3,
            AppTokens.sp3,
          ),
          leading: const Icon(
            Icons.build_circle_outlined,
            size: 18,
            color: AppTokens.text2,
          ),
          title: Text(
            'Resultado · ${entry.toolName}',
            style: textTheme.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                entry.content.isEmpty ? '(vacío)' : entry.content,
                style: textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: AppTokens.text2,
                ),
              ),
            ),
          ],
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
