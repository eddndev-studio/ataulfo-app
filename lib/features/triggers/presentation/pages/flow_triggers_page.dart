import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../flows/domain/entities/flow.dart' as fdom;
import '../../../flows/domain/failures/flows_failure.dart';
import '../../../flows/presentation/bloc/flow_detail_bloc.dart';
import '../../../labels/domain/repositories/labels_repository.dart';
import '../../../labels/presentation/bloc/labels_bloc.dart';
import '../../domain/entities/trigger.dart';
import '../../domain/failures/triggers_failure.dart';
import '../../domain/repositories/triggers_repository.dart';
import '../bloc/triggers_bloc.dart';
import '../widgets/trigger_edit_sheet.dart';

/// Página de disparadores de un flujo (`/flows/:id/triggers`). Los blocs
/// viven a nivel de ruta: el listado se pide UNA vez por visita, en vez
/// de refetchear en cada montaje como cuando era un tab.
///
/// La ruta solo conoce el id del flujo, pero el endpoint de triggers es
/// template-scoped y el sheet necesita el Flow entero (`scopedFlow`):
/// la página resuelve la cabecera desde su `FlowDetailBloc` propio y
/// recién entonces monta el scope de triggers.
class FlowTriggersPage extends StatelessWidget {
  const FlowTriggersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlowDetailBloc, FlowDetailState>(
      builder: (context, state) => switch (state) {
        FlowDetailLoading() => const AppLoadingIndicator(),
        FlowDetailLoaded(flow: final f) => FlowTriggersScope(flow: f),
        FlowDetailMutating(flow: final f) => FlowTriggersScope(flow: f),
        FlowDetailMutationFailed(flow: final f) => FlowTriggersScope(flow: f),
        FlowDetailDeleted() => const SizedBox.shrink(),
        FlowDetailFailed(failure: final f) => _HeaderFailedView(failure: f),
      },
    );
  }
}

/// La cabecera del flujo no cargó: sin ella no hay templateId para pedir
/// los disparadores. NotFound es terminal (sin retry).
class _HeaderFailedView extends StatelessWidget {
  const _HeaderFailedView({required this.failure});

  final FlowsFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is FlowsNotFoundFailure;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp5),
        child: AppErrorState(
          message: isNotFound
              ? 'Este flujo ya no existe en tu organización'
              : 'No pudimos cargar el flujo',
          onRetry: isNotFound
              ? null
              : () => context.read<FlowDetailBloc>().add(
                  const FlowDetailLoadRequested(),
                ),
        ),
      ),
    );
  }
}

/// Scope de blocs del listado. Construye su propio `TriggersBloc` (lee la
/// repo del scope) usando el `templateId` del flow — el endpoint sigue
/// siendo template-scoped (`GET /templates/:templateId/triggers`); el
/// filtro por `flowId` lo aplica el body al renderizar. Ownership real:
/// `Trigger ∈ Flow ∈ Template`; el endpoint template-scoped es un atajo
/// de query, no una afirmación de pertenencia.
///
/// También construye un `LabelsBloc` (carga única del catálogo
/// org-scoped) que alimenta el selector de etiqueta del sheet en modo
/// LABEL. Vive a nivel de página para reusar la carga entre aperturas del
/// sheet; el `_openSheet` lo re-provee al subtree del modal (el sheet
/// monta en una ruta nueva del Navigator y no hereda los providers).
///
/// Limitación aceptada de la carga única: si el operador crea o renombra
/// una etiqueta en otra sección y vuelve sin remontar la ruta, el
/// selector muestra el catálogo previo hasta que se recargue. Un id
/// borrado no se pierde: el selector lo muestra como "etiqueta
/// desconocida" con su id crudo.
class FlowTriggersScope extends StatelessWidget {
  const FlowTriggersScope({super.key, required this.flow});

  final fdom.Flow flow;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<TriggersBloc>(
          create: (innerCtx) => TriggersBloc(
            repo: innerCtx.read<TriggersRepository>(),
            templateId: flow.templateId,
          )..add(const TriggersLoadRequested()),
        ),
        BlocProvider<LabelsBloc>(
          create: (innerCtx) =>
              LabelsBloc(repo: innerCtx.read<LabelsRepository>())
                ..add(const LabelsLoadRequested()),
        ),
      ],
      child: FlowTriggersBody(flow: flow),
    );
  }
}

/// Consumer-only del `TriggersBloc` — render del listado filtrado por
/// `flow.id`. Vive público en el archivo para que los widget tests
/// puedan inyectar un bloc mockeado vía `BlocProvider.value` sin
/// pasar por el wrapper que construye la repo real.
///
/// Requiere además un `LabelsBloc` en el scope: `_openSheet` lo lee para
/// re-proveerlo al sheet (el selector de etiqueta del trigger LABEL). Un
/// test que monte este body directo debe proveer ambos blocs.
class FlowTriggersBody extends StatelessWidget {
  const FlowTriggersBody({super.key, required this.flow});

  final fdom.Flow flow;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TriggersBloc, TriggersState>(
      builder: (context, state) => switch (state) {
        TriggersLoading() => const Padding(
          key: Key('flow_triggers.loading'),
          padding: EdgeInsets.symmetric(vertical: AppTokens.sp6),
          child: AppLoadingIndicator(),
        ),
        TriggersLoaded(triggers: final ts) => _List(items: ts, flow: flow),
        // Mutating y MutationFailed preservan la lista visible — el
        // sheet abierto muestra spinner/copy propio; la página no
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

/// Abre el sheet de creación/edición con el flow del editor como
/// `scopedFlow`. `TriggerEditSheet.open` re-provee los blocs del scope
/// (el modal no hereda providers) y aplica el fondo canónico.
void _openSheet(BuildContext context, fdom.Flow flow, {Trigger? editing}) {
  TriggerEditSheet.open(context, scopedFlow: flow, editing: editing);
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
    final padding = EdgeInsets.fromLTRB(
      AppTokens.sp6,
      AppTokens.sp4,
      AppTokens.sp6,
      AppTokens.sp6 + context.safeBottomInset,
    );

    if (mine.isEmpty) {
      return SingleChildScrollView(
        padding: padding,
        child: AppEmptyState(
          key: const Key('flow_triggers.empty'),
          icon: Icons.bolt_outlined,
          title: 'Este flujo aún no tiene disparadores',
          description:
              'Un disparador lanza el flujo cuando un mensaje o una '
              'etiqueta coinciden. Sin disparadores, el flujo no corre solo.',
          ctaLabel: 'Crear disparador',
          ctaIcon: Icons.add,
          onCta: () => _openSheet(context, flow),
        ),
      );
    }
    // Dialecto denso de listas: UNA card apila las filas separadas por
    // divider hairline; el alta queda como acción de texto al pie.
    final rows = <Widget>[];
    for (var i = 0; i < mine.length; i++) {
      if (i > 0) {
        rows.add(
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
        );
      }
      final t = mine[i];
      rows.add(
        InkWell(
          key: Key('flow_triggers.row.${t.id}.tap'),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          onTap: () => _openSheet(context, flow, editing: t),
          child: _Row(trigger: t),
        ),
      );
    }
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: rows,
            ),
          ),
          const SizedBox(height: AppTokens.sp3),
          AppButton.text(
            key: const Key('flow_triggers.add_button'),
            label: '+ Disparador',
            onPressed: () => _openSheet(context, flow),
          ),
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
    final monoStyle = t.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const <String>['RobotoMono', 'Courier', 'monospace'],
    );
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
                child: isText
                    ? Text(
                        trigger.keyword,
                        style: monoStyle,
                        overflow: TextOverflow.ellipsis,
                      )
                    : BlocBuilder<LabelsBloc, LabelsState>(
                        builder: (context, lblState) {
                          final (text, mono) = _labelDisplay(
                            trigger.labelId,
                            lblState,
                          );
                          return Text(
                            text,
                            style: mono ? monoStyle : t.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
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
    // NotFound del template padre es terminal — reintentar el mismo id
    // volverá a fallar; no se ofrece botón de retry.
    final isNotFound = failure is TriggersNotFoundFailure;
    return Padding(
      padding: const EdgeInsets.all(AppTokens.sp6),
      child: AppErrorState(
        key: const Key('flow_triggers.failed'),
        message: isNotFound
            ? 'Este flujo ya no existe en tu organización; no hay '
                  'disparadores que cargar.'
            : 'No pudimos cargar los disparadores de este flujo',
        onRetry: isNotFound
            ? null
            : () => context.read<TriggersBloc>().add(
                const TriggersLoadRequested(),
              ),
      ),
    );
  }
}

/// Resuelve el `labelId` de un trigger LABEL a texto presentable, junto con
/// si debe renderizarse en monospace. Con el catálogo cargado: el nombre si el
/// id existe, o "Etiqueta eliminada" si no. Mientras carga o falló no podemos
/// afirmar ausencia, así que mostramos el id crudo (monospace) como placeholder
/// — nunca "eliminada", para no flashear texto erróneo antes de tener catálogo.
(String, bool) _labelDisplay(String labelId, LabelsState state) {
  if (state is LabelsLoaded) {
    for (final l in state.labels) {
      if (l.id == labelId) return (l.name, false);
    }
    return ('Etiqueta eliminada', false);
  }
  return (labelId, true);
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
