import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../flows/domain/entities/flow.dart' as fdom;
import '../../domain/entities/trigger.dart';
import '../../domain/failures/triggers_failure.dart';
import '../../domain/repositories/triggers_repository.dart';
import '../bloc/triggers_bloc.dart';
import 'trigger_edit_sheet.dart';

/// Tab "Disparadores" del editor de flujo (S11). El flow destino es el
/// flow del editor — fijo, no elegible — y las rows ocultan la pill
/// "→ flow" porque es redundante en este scope.
///
/// Construye su propio `TriggersBloc` (lee la repo del scope) usando
/// el `templateId` del flow del editor. El endpoint sigue siendo
/// template-scoped (`GET /templates/:templateId/triggers`) — el filtro
/// por `flowId` lo aplica el body al renderizar. Ownership real:
/// `Trigger ∈ Flow ∈ Template`; el endpoint template-scoped es un
/// atajo de query, no una afirmación de pertenencia.
class FlowTriggersTab extends StatelessWidget {
  const FlowTriggersTab({super.key, required this.flow});

  final fdom.Flow flow;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TriggersBloc>(
      create: (innerCtx) => TriggersBloc(
        repo: innerCtx.read<TriggersRepository>(),
        templateId: flow.templateId,
      )..add(const TriggersLoadRequested()),
      child: FlowTriggersBody(flow: flow),
    );
  }
}

/// Consumer-only del `TriggersBloc` — render del listado filtrado por
/// `flow.id`. Vive público en el archivo para que los widget tests
/// puedan inyectar un bloc mockeado vía `BlocProvider.value` sin
/// pasar por el wrapper que construye la repo real.
class FlowTriggersBody extends StatelessWidget {
  const FlowTriggersBody({super.key, required this.flow});

  final fdom.Flow flow;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TriggersBloc, TriggersState>(
      builder: (context, state) => switch (state) {
        TriggersLoading() => const Padding(
          key: Key('flow_triggers.loading'),
          padding: EdgeInsets.symmetric(vertical: AppTokens.sp4),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        TriggersLoaded(triggers: final ts) => _List(items: ts, flow: flow),
        // Mutating y MutationFailed preservan la lista visible — el
        // sheet abierto muestra spinner/copy propio; el tab no
        // ensombrece su propia render mientras tanto.
        TriggersMutating(triggers: final ts) => _List(items: ts, flow: flow),
        TriggersMutationFailed(triggers: final ts) => _List(
          items: ts,
          flow: flow,
        ),
        TriggersFailed(failure: final f) => _FailedView(failure: f),
      },
    );
  }
}

/// Abre el sheet de creación/edición pasando el bloc del scope y el
/// flow del editor como `scopedFlow`. El sheet ya sabe que no hay
/// `FlowsBloc` y oculta el dropdown.
void _openSheet(BuildContext context, fdom.Flow flow, {Trigger? editing}) {
  final bloc = context.read<TriggersBloc>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BlocProvider<TriggersBloc>.value(
      value: bloc,
      child: Padding(
        padding: EdgeInsets.only(bottom: context.sheetBottomInset),
        child: TriggerEditSheet(editing: editing, scopedFlow: flow),
      ),
    ),
  );
}

class _List extends StatelessWidget {
  const _List({required this.items, required this.flow});

  final List<Trigger> items;
  final fdom.Flow flow;

  @override
  Widget build(BuildContext context) {
    final mine = items
        .where((t) => t.flowId == flow.id)
        .toList(growable: false);
    final addButton = Align(
      alignment: Alignment.centerLeft,
      child: AppButton.text(
        key: const Key('flow_triggers.add_button'),
        label: '+ Disparador',
        onPressed: () => _openSheet(context, flow),
      ),
    );
    final padding = EdgeInsets.fromLTRB(
      AppTokens.sp6,
      AppTokens.sp4,
      AppTokens.sp6,
      AppTokens.sp6 + context.safeBottomInset,
    );

    if (mine.isEmpty) {
      return SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Este flujo aún no tiene disparadores.',
              key: const Key('flow_triggers.empty'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppTokens.text2,
              ),
            ),
            const SizedBox(height: AppTokens.sp2),
            addButton,
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final t in mine)
            InkWell(
              key: Key('flow_triggers.row.${t.id}.tap'),
              onTap: () => _openSheet(context, flow, editing: t),
              child: _Row(trigger: t),
            ),
          const SizedBox(height: AppTokens.sp2),
          addButton,
        ],
      ),
    );
  }
}

/// Row read-only del trigger. Sin pill "→ flow" — el scope ya es el
/// flow del editor, repetirlo cada row es ruido.
class _Row extends StatelessWidget {
  const _Row({required this.trigger});

  final Trigger trigger;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isText = trigger.triggerType == TriggerType.text;
    return Padding(
      key: Key('flow_triggers.row.${trigger.id}'),
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
                  key: Key('flow_triggers.row.${trigger.id}.status_pill'),
                  label: 'Activo',
                  dot: AppPillDot.active,
                )
              else
                AppPill.neutral(
                  key: Key('flow_triggers.row.${trigger.id}.status_pill'),
                  label: 'Pausado',
                  dot: AppPillDot.paused,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              if (isText)
                AppPill.outline(label: _matchLabel(trigger.matchType!))
              else if (trigger.labelAction != null)
                AppPill.outline(label: _labelActionLabel(trigger.labelAction!)),
              if (isText) AppPill.outline(label: _scopeLabel(trigger.scope)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final TriggersFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // NotFound del template padre es terminal — reintentar el mismo id
    // volverá a fallar; no se ofrece botón de retry.
    if (failure is TriggersNotFoundFailure) {
      return Padding(
        key: const Key('flow_triggers.failed'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp6,
          vertical: AppTokens.sp4,
        ),
        child: Text(
          'Este flujo ya no existe en tu organización; no hay disparadores que cargar.',
          style: textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
        ),
      );
    }
    return Padding(
      key: const Key('flow_triggers.failed'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp6,
        vertical: AppTokens.sp4,
      ),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              'No pudimos cargar los disparadores de este flujo.',
              style: TextStyle(color: AppTokens.danger),
            ),
          ),
          AppButton.text(
            label: 'Reintentar',
            onPressed: () =>
                context.read<TriggersBloc>().add(const TriggersLoadRequested()),
          ),
        ],
      ),
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
