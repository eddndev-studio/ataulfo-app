import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/flow.dart' as fdom;
import '../../domain/entities/step.dart' as sdom;
import '../../domain/failures/flows_failure.dart';
import '../bloc/flow_detail_bloc.dart';
import '../bloc/flow_steps_bloc.dart';
import '../widgets/step_edit_sheet.dart';

/// Detalle de un Flow (S11). Stateful para sostener el TabController de
/// las 3 secciones del editor: Pasos / Disparadores / Configuración. El
/// cableado del Scaffold y el AppBar los aporta la ruta `/flows/:id`; el
/// page entrega el shell del TabBar más el contenido por tab.
///
/// El TabBar solo aparece en Loaded — en Loading/Failed no tiene sentido
/// porque el operador todavía no puede operar el flow. El TabController
/// vive en _State y se reusa entre rebuilds del bloc.
class FlowDetailPage extends StatefulWidget {
  const FlowDetailPage({super.key});

  @override
  State<FlowDetailPage> createState() => _FlowDetailPageState();
}

class _FlowDetailPageState extends State<FlowDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlowDetailBloc, FlowDetailState>(
      builder: (context, state) => switch (state) {
        FlowDetailLoading() => const _LoadingView(),
        FlowDetailLoaded(flow: final f) => _LoadedShell(tab: _tab, flow: f),
        FlowDetailFailed(failure: final f) => _FailedView(failure: f),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
}

/// Shell del Loaded: TabBar fijo arriba + TabBarView con las 3 secciones
/// del editor. El TabController lo aporta el _State del page para que
/// sobreviva a los rebuilds del bloc; los tabs son fijos (3 secciones
/// estables del editor).
class _LoadedShell extends StatelessWidget {
  const _LoadedShell({required this.tab, required this.flow});

  final TabController tab;
  final fdom.Flow flow;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Material(
          color: AppTokens.surface1,
          child: TabBar(
            controller: tab,
            tabs: const <Widget>[
              Tab(text: 'Pasos'),
              Tab(text: 'Disparadores'),
              Tab(text: 'Configuración'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: tab,
            children: <Widget>[
              _StepsTab(flow: flow),
              const _ComingSoonTab(
                tabKey: Key('flow_detail.tab.triggers.coming_soon'),
                title: 'Disparadores',
                copy:
                    'Los disparadores se administran desde la plantilla. '
                    'Próximamente verás aquí los que apuntan a este flujo.',
              ),
              const _ComingSoonTab(
                tabKey: Key('flow_detail.tab.settings.coming_soon'),
                title: 'Configuración',
                copy:
                    'Próximamente: cooldown, límite de uso y exclusiones '
                    'entre flujos.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tab de Pasos. El header del flow (nombre + pills v/status) se renderiza
/// siempre — viene de `FlowDetailBloc.Loaded`, que ya está resuelto cuando
/// el shell se monta. La lista de StepCards depende del `FlowStepsBloc`
/// propio del tab, con sus tres estados (Loading/Loaded/Failed).
///
/// Header fijo en la parte superior + lista expandible abajo: para que
/// el `ReorderableListView` (cuando hay ≥2 steps) tenga el viewport
/// bounded que necesita para el drag&drop. Que el header viva fuera
/// del listado permite render progresivo: el operador ve qué flujo
/// está editando aunque `/flows/:id/steps` siga en vuelo o falle.
class _StepsTab extends StatelessWidget {
  const _StepsTab({required this.flow});

  final fdom.Flow flow;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.sp6,
            AppTokens.sp6,
            AppTokens.sp6,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(flow.name, style: textTheme.titleLarge),
              const SizedBox(height: AppTokens.sp3),
              Wrap(
                spacing: AppTokens.sp2,
                runSpacing: AppTokens.sp2,
                children: <Widget>[
                  AppPill.outline(label: 'v${flow.version}'),
                  if (flow.isActive)
                    const AppPill.primary(
                      label: 'Activo',
                      dot: AppPillDot.active,
                    )
                  else
                    const AppPill.neutral(
                      label: 'Pausado',
                      dot: AppPillDot.paused,
                    ),
                ],
              ),
              const SizedBox(height: AppTokens.sp6),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton.text(
                  key: const Key('flow_detail.steps.add_button'),
                  label: 'Nuevo paso',
                  icon: Icons.add,
                  onPressed: () => _openStepSheet(context, null),
                ),
              ),
              const SizedBox(height: AppTokens.sp3),
            ],
          ),
        ),
        const Expanded(child: _StepsList()),
      ],
    );
  }
}

/// Lista de StepCards atada al `FlowStepsBloc`. Loading muestra spinner
/// inline (no centrado en pantalla, ya que el header vive arriba).
/// Failed muestra mensaje + retry; NotFound se trata como mensaje
/// terminal sin botón.
class _StepsList extends StatelessWidget {
  const _StepsList();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<FlowStepsBloc, FlowStepsState>(
      builder: (context, state) => switch (state) {
        FlowStepsLoading() => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppTokens.sp4),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
            ),
          ),
        ),
        FlowStepsLoaded(steps: final ss) => _StepsListView(
          steps: ss,
          textTheme: textTheme,
        ),
        // Mutating y MutationFailed mantienen la lista visible (snapshot
        // preservado) para que el operador no pierda contexto mientras la
        // mutación está en curso o tras un fallo recuperable.
        FlowStepsMutating(steps: final ss) => _StepsListView(
          steps: ss,
          textTheme: textTheme,
          isMutating: true,
        ),
        FlowStepsMutationFailed(steps: final ss) => _StepsListView(
          steps: ss,
          textTheme: textTheme,
        ),
        FlowStepsFailed(failure: final f) => _StepsFailedView(failure: f),
      },
    );
  }
}

/// Renderiza la lista de StepCards o el empty state. `isMutating` agrega
/// un spinner inline al inicio (no overlay) para indicar que una
/// mutación está en curso sin tapar la lista existente.
///
/// Con ≥2 steps usa `ReorderableListView.builder` para soportar drag&drop.
/// Con 0 o 1 step usa un layout simple — no tiene sentido pagar el costo
/// del scroll de reorder cuando no hay nada que reordenar.
class _StepsListView extends StatelessWidget {
  const _StepsListView({
    required this.steps,
    required this.textTheme,
    this.isMutating = false,
  });

  final List<sdom.Step> steps;
  final TextTheme textTheme;
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    final viewPaddingBottom = MediaQuery.viewPaddingOf(context).bottom;
    final listPadding = EdgeInsets.fromLTRB(
      AppTokens.sp6,
      0,
      AppTokens.sp6,
      AppTokens.sp6 + viewPaddingBottom,
    );
    final bloc = context.read<FlowStepsBloc>();

    if (steps.isEmpty) {
      return SingleChildScrollView(
        padding: listPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (isMutating) ...<Widget>[
              const _MutatingInlineSpinner(),
              const SizedBox(height: AppTokens.sp3),
            ],
            Text(
              'Este flujo aún no tiene pasos.',
              key: const Key('flow_detail.steps.empty'),
              style: textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppTokens.text2,
              ),
            ),
          ],
        ),
      );
    }

    if (steps.length == 1) {
      return SingleChildScrollView(
        padding: listPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (isMutating) ...<Widget>[
              const _MutatingInlineSpinner(),
              const SizedBox(height: AppTokens.sp3),
            ],
            _StepCard(step: steps.first),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (isMutating) ...<Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTokens.sp6),
            child: _MutatingInlineSpinner(),
          ),
          const SizedBox(height: AppTokens.sp3),
        ],
        Expanded(
          child: ReorderableListView.builder(
            padding: listPadding,
            itemCount: steps.length,
            buildDefaultDragHandles: false,
            itemBuilder: (_, i) {
              final s = steps[i];
              return Padding(
                key: ValueKey<String>('flow_detail.step_card.row.${s.id}'),
                padding: const EdgeInsets.only(bottom: AppTokens.sp3),
                child: _StepCard(step: s, dragIndex: i),
              );
            },
            onReorder: (oldIdx, newIdx) {
              // ReorderableListView semántica: al mover hacia abajo, el
              // newIdx que entrega ya cuenta el slot que el item dejó
              // libre, así que conviene normalizarlo restando 1.
              final adjusted = newIdx > oldIdx ? newIdx - 1 : newIdx;
              final ids = <String>[for (final s in steps) s.id];
              final moved = ids.removeAt(oldIdx);
              ids.insert(adjusted, moved);
              bloc.add(FlowStepsReorderRequested(ids));
            },
          ),
        ),
      ],
    );
  }
}

class _MutatingInlineSpinner extends StatelessWidget {
  const _MutatingInlineSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: Key('flow_detail.steps.mutating'),
    height: 2,
    child: LinearProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
}

class _StepsFailedView extends StatelessWidget {
  const _StepsFailedView({required this.failure});

  final FlowsFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is FlowsNotFoundFailure;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: isNotFound
          ? const Key('flow_detail.steps.error.not_found')
          : const Key('flow_detail.steps.error.generic'),
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isNotFound
                ? 'No pudimos encontrar los pasos de este flujo.'
                : 'No pudimos cargar los pasos.',
            style: textTheme.bodyMedium,
          ),
          if (!isNotFound) ...<Widget>[
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<FlowStepsBloc>().add(
                const FlowStepsLoadRequested(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder para tabs aún no implementadas. Centra un mensaje breve
/// para que el operador entienda que la sección existe pero no está
/// lista todavía — evita confusión por tab "vacía".
class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({
    required this.tabKey,
    required this.title,
    required this.copy,
  });

  final Key tabKey;
  final String title;
  final String copy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: tabKey,
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: AppTokens.sp2),
            Text(
              'Próximamente',
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.sp3),
            Text(
              copy,
              style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card read-only por step. Muestra index (order+1), label humanizado del
/// type, contenido (`content` para TEXT, `mediaRef` para multimedia,
/// resumen de metadata para CONDITIONAL_TIME), y pills laterales (delay,
/// aiOnly si aplica).
///
/// `dragIndex != null` ⇒ se renderiza con drag handle a la derecha,
/// listo para reordenar dentro del `ReorderableListView` padre. El handle
/// captura el gesto antes del InkWell (se monta como sibling del área
/// tappable), así que long-press/drag sobre el handle no abre el sheet.
class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, this.dragIndex});

  final sdom.Step step;
  final int? dragIndex;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '${step.order + 1}.',
              style: textTheme.titleMedium?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(width: AppTokens.sp2),
            Text(_humanLabelFor(step.type), style: textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: AppTokens.sp2),
        _StepBody(step: step, textTheme: textTheme),
        const SizedBox(height: AppTokens.sp3),
        Wrap(
          spacing: AppTokens.sp2,
          runSpacing: AppTokens.sp2,
          children: <Widget>[
            AppPill.neutral(label: _delayLabel(step)),
            if (step.aiOnly) const AppPill.primary(label: 'Solo IA'),
          ],
        ),
      ],
    );
    final dragIdx = dragIndex;
    return AppCard(
      padding: AppTokens.sp4,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: InkWell(
              key: Key('flow_detail.step_card.${step.id}'),
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              onTap: () => _openStepSheet(context, step),
              child: content,
            ),
          ),
          if (dragIdx != null)
            ReorderableDragStartListener(
              index: dragIdx,
              child: Padding(
                padding: const EdgeInsets.only(left: AppTokens.sp2),
                child: Icon(
                  Icons.drag_handle,
                  key: Key('flow_detail.step_card.drag_handle.${step.id}'),
                  color: AppTokens.text2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Abre el sheet de edición pasando el FlowStepsBloc del scope y, si
/// `step` viene, el step a editar. La función vive a nivel de archivo
/// porque la usan tanto _StepsTab (botón "Nuevo paso") como _StepCard
/// (tap del card).
void _openStepSheet(BuildContext context, sdom.Step? step) {
  final bloc = context.read<FlowStepsBloc>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => BlocProvider<FlowStepsBloc>.value(
      value: bloc,
      child: StepEditSheet(editing: step),
    ),
  );
}

/// Cuerpo del step según tipo. TEXT muestra content; multimedia muestra
/// mediaRef truncado; CONDITIONAL_TIME muestra placeholder ya que F2 no
/// interpreta metadata (F7 lo hará).
class _StepBody extends StatelessWidget {
  const _StepBody({required this.step, required this.textTheme});

  final sdom.Step step;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final t = step.type;
    if (t == sdom.StepType.text) {
      final content = step.content.isEmpty ? '—' : step.content;
      return Text(
        content,
        style: textTheme.bodyMedium?.copyWith(
          color: step.content.isEmpty ? AppTokens.text2 : null,
        ),
      );
    }
    if (t == sdom.StepType.conditionalTime) {
      return Text(
        'Condicional por horario (configurable en el editor).',
        style: textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      );
    }
    // Multimedia: IMAGE / VIDEO / DOCUMENT / AUDIO / PTT / STICKER.
    if (step.mediaRef.isEmpty) {
      return Text(
        'Sin media asignada',
        style: textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          step.mediaRef,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            color: AppTokens.text2,
          ),
        ),
        if (step.content.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppTokens.sp1),
          Text(step.content, style: textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final FlowsFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is FlowsNotFoundFailure;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: isNotFound
          ? const Key('flow_detail.error.not_found')
          : const Key('flow_detail.error.generic'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              isNotFound
                  ? 'Este flujo ya no existe en tu organización'
                  : 'No pudimos cargar el detalle del flujo',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            if (!isNotFound) ...<Widget>[
              const SizedBox(height: AppTokens.sp3),
              AppButton.tonal(
                label: 'Reintentar',
                onPressed: () => context.read<FlowDetailBloc>().add(
                  const FlowDetailLoadRequested(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _humanLabelFor(sdom.StepType t) => switch (t) {
  sdom.StepType.text => 'Texto',
  sdom.StepType.image => 'Imagen',
  sdom.StepType.video => 'Video',
  sdom.StepType.document => 'Documento',
  sdom.StepType.audio => 'Audio',
  sdom.StepType.ptt => 'Nota de voz',
  sdom.StepType.sticker => 'Sticker',
  sdom.StepType.conditionalTime => 'Condicional',
};

/// Etiqueta legible del delay. Convierte ms a segundos con un decimal y
/// agrega el jitter si > 0. Ejemplos: "0s" / "1.5s" / "2s ± 10%".
String _delayLabel(sdom.Step s) {
  final secs = s.delayMs / 1000;
  final base = secs == secs.truncate()
      ? '${secs.toInt()}s'
      : '${secs.toStringAsFixed(1)}s';
  if (s.jitterPct <= 0) return base;
  return '$base ± ${s.jitterPct}%';
}
