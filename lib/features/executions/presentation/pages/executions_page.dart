import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/util/smart_timestamp.dart';
import '../../domain/entities/execution.dart';
import '../../domain/failures/execution_failure.dart';
import '../cubit/executions_cubit.dart';

/// Historial de ejecuciones de flujo de un chat (ADMIN+): qué flujos corrieron,
/// con qué estado, cuándo y —si fallaron— por qué (el error crudo del motor).
/// Es la superficie de triage en producción del send_failed/timeout que el
/// operador ve sin entender el código.
class ExecutionsPage extends StatelessWidget {
  const ExecutionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExecutionsCubit, ExecutionsState>(
      builder: (context, state) => switch (state) {
        ExecutionsLoading() => const Center(
          key: Key('executions.loading'),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
          ),
        ),
        ExecutionsFailed(failure: final f) => _FailedView(failure: f),
        ExecutionsLoaded() => _LoadedView(state: state),
      },
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state});

  final ExecutionsLoaded state;

  @override
  Widget build(BuildContext context) {
    if (state.executions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppTokens.sp6),
          child: Text(
            'Este chat aún no tiene ejecuciones de flujo.',
            key: Key('executions.empty'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTokens.text2),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppTokens.sp4),
      itemCount: state.executions.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTokens.sp3),
      itemBuilder: (_, i) {
        final e = state.executions[i];
        return _ExecutionRow(execution: e, flowName: state.flowNames[e.flowId]);
      },
    );
  }
}

class _ExecutionRow extends StatelessWidget {
  const _ExecutionRow({required this.execution, required this.flowName});

  final Execution execution;
  final String? flowName;

  @override
  Widget build(BuildContext context) {
    // Nombre resuelto si lo hay; si no, el id crudo (un flujo borrado/inactivo
    // no aparece en el catálogo corrible). El operador siempre tiene el id.
    final title = (flowName != null && flowName!.isNotEmpty)
        ? flowName!
        : 'Flujo ${execution.flowId}';
    final showError =
        execution.status == ExecutionStatus.failed &&
        execution.error.isNotEmpty;
    return AppCard(
      key: Key('executions.item.${execution.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTokens.text1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.sp3),
              _statusPill(execution.status),
            ],
          ),
          const SizedBox(height: AppTokens.sp2),
          Text(
            smartTimestamp(execution.startedAt.millisecondsSinceEpoch),
            style: const TextStyle(
              color: AppTokens.textDisabled,
              fontSize: AppTokens.captionSize,
              fontWeight: AppTokens.captionWeight,
            ),
          ),
          if (showError) ...<Widget>[
            const SizedBox(height: AppTokens.sp3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTokens.sp3),
              decoration: BoxDecoration(
                color: AppTokens.surface3,
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: SelectableText(
                execution.error,
                style: const TextStyle(
                  color: AppTokens.danger,
                  fontFamily: 'monospace',
                  fontSize: AppTokens.captionSize,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _statusPill(ExecutionStatus status) {
    return switch (status) {
      ExecutionStatus.failed => const AppPill.danger(
        label: 'Fallido',
        dot: AppPillDot.danger,
      ),
      ExecutionStatus.completed => const AppPill.primary(label: 'Completado'),
      ExecutionStatus.running => const AppPill.outline(
        label: 'En curso',
        dot: AppPillDot.active,
      ),
      ExecutionStatus.unknown => const AppPill.neutral(label: '—'),
    };
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final ExecutionFailure failure;

  @override
  Widget build(BuildContext context) {
    final message = switch (failure) {
      ExecutionForbiddenFailure() =>
        'Necesitas permisos de administrador para ver el historial.',
      ExecutionNetworkFailure() =>
        'Sin conexión. Revisa tu red e inténtalo de nuevo.',
      ExecutionUnknownFailure() =>
        'No se pudo cargar el historial de ejecuciones.',
    };
    return Center(
      key: const Key('executions.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTokens.text2),
            ),
            if (failure is! ExecutionForbiddenFailure) ...<Widget>[
              const SizedBox(height: AppTokens.sp4),
              AppButton.tonal(
                key: const Key('executions.retry'),
                label: 'Reintentar',
                icon: Icons.refresh,
                onPressed: () => context.read<ExecutionsCubit>().load(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
