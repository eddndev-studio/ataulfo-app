import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../flows/domain/entities/flow.dart' as fdom;
import '../../../flows/presentation/bloc/flows_bloc.dart';
import '../../domain/entities/trigger.dart';
import '../../domain/failures/triggers_failure.dart';
import '../bloc/triggers_bloc.dart';

/// Sección read-only de Disparadores embebida en `TemplateDetailPage`.
///
/// Compone los estados de [TriggersBloc] y [FlowsBloc] del mismo scope:
/// la sección lee ambos para resolver `Trigger.flowId` → `Flow.name` y
/// pasa ese nombre resuelto a cada row. Si FlowsBloc todavía no terminó
/// (Loading) o el id no aparece en su Loaded (flow archivado/borrado),
/// la row cae al fallback de id truncado en monospace.
///
/// El widget vive en su propia feature (no como `_` privado de la page)
/// para no inflar `template_detail_page.dart` y porque F8 lo va a
/// extender con acciones (editar/borrar/crear) sin tocar la página.
class TriggersSection extends StatelessWidget {
  const TriggersSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TriggersBloc, TriggersState>(
      builder: (context, state) => switch (state) {
        TriggersLoading() => const Padding(
          key: Key('triggers.loading'),
          padding: EdgeInsets.symmetric(vertical: AppTokens.sp2),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        TriggersLoaded(triggers: final ts) => _TriggersList(items: ts),
        TriggersFailed(failure: final f) => _TriggersFailedView(failure: f),
      },
    );
  }
}

class _TriggersList extends StatelessWidget {
  const _TriggersList({required this.items});

  final List<Trigger> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'Esta plantilla aún no tiene disparadores.',
        key: const Key('triggers.empty'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      );
    }
    return BlocBuilder<FlowsBloc, FlowsState>(
      builder: (context, flowsState) {
        final flowsById = _flowsIndexFromState(flowsState);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final t in items)
              _TriggerRow(trigger: t, resolvedFlowName: flowsById[t.flowId]),
          ],
        );
      },
    );
  }

  /// Indexa `Flow.id → Flow` desde el estado vigente del FlowsBloc.
  /// Loading/Failed devuelven mapa vacío — el row decide el fallback.
  Map<String, fdom.Flow> _flowsIndexFromState(FlowsState state) {
    if (state is FlowsLoaded) {
      return <String, fdom.Flow>{for (final f in state.flows) f.id: f};
    }
    return const <String, fdom.Flow>{};
  }
}

class _TriggerRow extends StatelessWidget {
  const _TriggerRow({required this.trigger, required this.resolvedFlowName});

  final Trigger trigger;
  final fdom.Flow? resolvedFlowName;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isText = trigger.triggerType == TriggerType.text;
    return Padding(
      key: Key('triggers.row.${trigger.id}'),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Text(
                  isText ? trigger.keyword : trigger.labelId,
                  style: t.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontFamilyFallback: const <String>[
                      'RobotoMono',
                      'Courier',
                      'monospace',
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trigger.isActive)
                AppPill.primary(
                  key: Key('triggers.row.${trigger.id}.status_pill'),
                  label: 'Activo',
                  dot: AppPillDot.active,
                )
              else
                AppPill.neutral(
                  key: Key('triggers.row.${trigger.id}.status_pill'),
                  label: 'Pausado',
                  dot: AppPillDot.paused,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (isText)
                AppPill.outline(label: _matchLabel(trigger.matchType!))
              else if (trigger.labelAction != null)
                AppPill.outline(label: _labelActionLabel(trigger.labelAction!)),
              if (isText) AppPill.outline(label: _scopeLabel(trigger.scope)),
              _FlowTarget(
                trigger: trigger,
                resolvedFlow: resolvedFlowName,
                style: t.bodySmall?.copyWith(color: AppTokens.text2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowTarget extends StatelessWidget {
  const _FlowTarget({
    required this.trigger,
    required this.resolvedFlow,
    required this.style,
  });

  final Trigger trigger;
  final fdom.Flow? resolvedFlow;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final flow = resolvedFlow;
    if (flow != null) {
      return Text('→ ${flow.name}', style: style);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('→ ', style: style),
        Text(
          trigger.flowId,
          key: Key('triggers.row.${trigger.id}.flow_fallback'),
          style: style?.copyWith(
            fontFamily: 'monospace',
            fontFamilyFallback: const <String>[
              'RobotoMono',
              'Courier',
              'monospace',
            ],
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _TriggersFailedView extends StatelessWidget {
  const _TriggersFailedView({required this.failure});

  final TriggersFailure failure;

  @override
  Widget build(BuildContext context) {
    // NotFound es terminal — la Template padre no existe (o fue
    // borrada). Reintentar el mismo id volverá a fallar; no se ofrece
    // botón de retry para no inducir un loop al operador.
    if (failure is TriggersNotFoundFailure) {
      return Text(
        'La plantilla padre ya no existe; no hay disparadores que cargar.',
        key: const Key('triggers.failed'),
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
      );
    }
    return Row(
      key: const Key('triggers.failed'),
      children: <Widget>[
        const Expanded(
          child: Text(
            'No pudimos cargar los disparadores.',
            style: TextStyle(color: AppTokens.danger),
          ),
        ),
        AppButton.text(
          label: 'Reintentar',
          onPressed: () =>
              context.read<TriggersBloc>().add(const TriggersLoadRequested()),
        ),
      ],
    );
  }
}

String _matchLabel(MatchType m) => switch (m) {
  MatchType.exact => 'Exacto',
  MatchType.contains => 'Contiene',
  MatchType.regex => 'Regex',
};

String _scopeLabel(TriggerScope s) => switch (s) {
  TriggerScope.incoming => 'Entrante',
  TriggerScope.outgoing => 'Saliente',
  TriggerScope.both => 'Ambos',
};

String _labelActionLabel(LabelAction a) => switch (a) {
  LabelAction.add => 'Agregar etiqueta',
  LabelAction.remove => 'Quitar etiqueta',
};
