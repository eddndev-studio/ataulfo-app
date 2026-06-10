// Pesa >400 LOC porque agrupa el shell del editor + helpers cohesivos
// del tab Pasos (lista, drag&drop, StepCard, body por tipo). Cualquier
// split implicaría compartir varias estructuras privadas entre archivos
// hermanos sin ganancia real de reutilización — los widgets viven solo
// aquí. Si el shell crece más con los tabs Triggers/Settings, extraer
// _StepCard + _StepBody a `widgets/step_card.dart` será el primer corte.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../labels/domain/repositories/labels_repository.dart';
import '../../../labels/presentation/bloc/labels_bloc.dart';
import '../../../media/domain/entities/media_asset.dart';
import '../../../triggers/presentation/widgets/flow_triggers_tab.dart';
import '../../domain/entities/conditional_time_metadata.dart';
import '../../domain/entities/flow.dart' as fdom;
import '../../domain/entities/label_step_metadata.dart';
import '../../domain/entities/step.dart' as sdom;
import '../../domain/failures/flows_failure.dart';
import '../bloc/flow_detail_bloc.dart';
import '../bloc/flow_steps_bloc.dart';
import '../bloc/media_names_cubit.dart';
import '../media_step_name.dart';
import '../widgets/conditional_time_day_mapping.dart';
import '../widgets/flow_settings_tab.dart';
import '../widgets/step_edit_sheet.dart';
import '../widgets/step_type_label.dart';

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
        // Mientras la mutación de Settings está en vuelo o falló, el
        // shell sigue visible con el flow del snapshot: el tab Pasos
        // y Triggers ven la misma cabecera; el tab Configuración lee
        // el estado directamente y actualiza su UX.
        FlowDetailSettingsSaving(flow: final f) => _LoadedShell(
          tab: _tab,
          flow: f,
        ),
        FlowDetailSettingsSaveFailed(flow: final f) => _LoadedShell(
          tab: _tab,
          flow: f,
        ),
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
              FlowTriggersTab(
                key: const Key('flow_detail.tab.triggers'),
                flow: flow,
              ),
              const FlowSettingsTab(key: Key('flow_detail.tab.settings')),
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
    return BlocConsumer<FlowStepsBloc, FlowStepsState>(
      // Sólo el reorder muta sin un sheet delante: add/edit/delete reportan
      // su fallo inline dentro del sheet abierto. El gate `isCurrent` evita
      // duplicar el aviso cuando el fallo ocurre con un modal encima.
      listener: (context, state) {
        if (state is FlowStepsMutationFailed &&
            (ModalRoute.of(context)?.isCurrent ?? true)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'No se pudo guardar el nuevo orden. Se revirtieron los '
                  'cambios.',
                ),
              ),
            );
        }
      },
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
    final listPadding = EdgeInsets.fromLTRB(
      AppTokens.sp6,
      0,
      AppTokens.sp6,
      AppTokens.sp6 + context.safeBottomInset,
    );
    final bloc = context.read<FlowStepsBloc>();
    // Resuelve los nombres EN VIVO del catálogo UNA vez, POR ENCIMA del
    // ReorderableListView, y se los pasa a cada tarjeta como dato plano. Si el
    // lookup del cubit viviera dentro del item reordenable, al arrastrarlo el
    // item se eleva al overlay del Navigator (fuera del scope del provider) y
    // el lookup lanzaría ProviderNotFound → RenderErrorBox gris estirado.
    final namesState = context.watch<MediaNamesCubit>().state;
    // Mismo patrón para el catálogo de labels: mapa plano id→nombre para que
    // el paso LABEL muestre el nombre y no el UUID.
    final labelsState = context.watch<LabelsBloc>().state;
    final labelNames = labelsState is LabelsLoaded
        ? <String, String>{for (final l in labelsState.labels) l.id: l.name}
        : const <String, String>{};

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
            _StepCard(
              step: steps.first,
              resolvedMediaName: namesState.nameFor(steps.first.mediaRef),
              labelNames: labelNames,
            ),
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
                child: _StepCard(
                  step: s,
                  dragIndex: i,
                  resolvedMediaName: namesState.nameFor(s.mediaRef),
                  labelNames: labelNames,
                ),
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
  const _StepCard({
    required this.step,
    this.dragIndex,
    this.resolvedMediaName,
    this.labelNames = const <String, String>{},
  });

  final sdom.Step step;
  final int? dragIndex;

  /// Nombre EN VIVO del recurso multimedia ya resuelto por el caller (lee el
  /// `MediaNamesCubit` por encima del listado). Plano a propósito: ver
  /// [_StepBody.resolvedMediaName].
  final String? resolvedMediaName;

  /// Catálogo id→nombre de labels, resuelto por el caller por encima del
  /// listado (mismo motivo de planitud que [resolvedMediaName]).
  final Map<String, String> labelNames;

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
            AppPill.outline(label: stepTypeLabel(step.type)),
          ],
        ),
        const SizedBox(height: AppTokens.sp2),
        _StepBody(
          step: step,
          textTheme: textTheme,
          resolvedMediaName: resolvedMediaName,
          labelNames: labelNames,
        ),
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
              // 48x48: área de agarre táctil mínima (el ícono solo mide 24 y
              // es demasiado fino para el pulgar). ExcludeSemantics colapsa el
              // nodo del ícono en uno solo con la etiqueta de acción.
              child: Semantics(
                label: 'Mover paso',
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.drag_handle,
                      key: Key('flow_detail.step_card.drag_handle.${step.id}'),
                      color: AppTokens.text2,
                    ),
                  ),
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
  final labelsRepo = context.read<LabelsRepository>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<FlowStepsBloc>.value(value: bloc),
        // LabelsBloc para el selector del paso LABEL (carga única del catálogo
        // org-scoped). Si el usuario no elige LABEL, el bloc carga igual —
        // barato — y se descarta al cerrar el sheet.
        BlocProvider<LabelsBloc>(
          create: (_) =>
              LabelsBloc(repo: labelsRepo)..add(const LabelsLoadRequested()),
        ),
      ],
      // Al crear o reemplazar el recurso de un step multimedia, el selector
      // abre la galería en modo picker (`/media/pick?type=<familia>`, filtrada
      // por el tipo del paso) que devuelve el MediaAsset completo vía pop. Se
      // cablea igual al crear y al editar; el sheet decide la interactividad
      // según el tipo de step y aporta la familia.
      child: StepEditSheet(
        editing: step,
        pickMediaRef: (ctx, family) => ctx.push<MediaAsset>(
          family == null ? '/media/pick' : '/media/pick?type=$family',
        ),
      ),
    ),
  );
}

/// Cuerpo del step según tipo. TEXT muestra content; multimedia muestra
/// mediaRef truncado; CONDITIONAL_TIME interpreta `metadataJson` y
/// muestra TZ + ventanas formateadas + destinos onMatch/onElse. Si el
/// metadata no parsea (corrupto/legacy), cae a un fallback honesto.
class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.step,
    required this.textTheme,
    this.resolvedMediaName,
    this.labelNames = const <String, String>{},
  });

  final sdom.Step step;
  final TextTheme textTheme;

  /// Catálogo id→nombre de labels, plano por el mismo motivo que
  /// [resolvedMediaName].
  final Map<String, String> labelNames;

  /// Nombre EN VIVO del recurso (alias/filename del catálogo) ya resuelto por
  /// el caller, que lee el `MediaNamesCubit` POR ENCIMA del `ReorderableListView`.
  /// Se recibe como dato plano —no se hace lookup del cubit aquí— para que el
  /// subárbol de la tarjeta sea autocontenido: al reordenar, el item se eleva al
  /// overlay del Navigator (fuera del scope del provider) y un lookup ahí
  /// lanzaría ProviderNotFound (RenderErrorBox gris estirado). null ⇒ aún
  /// cargando o asset borrado (el respaldo por paso decide el texto).
  final String? resolvedMediaName;

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
      return _ConditionalTimeSummary(step: step, textTheme: textTheme);
    }
    if (t == sdom.StepType.label) {
      return _LabelStepSummary(
        step: step,
        textTheme: textTheme,
        labelNames: labelNames,
      );
    }
    if (t == sdom.StepType.unsupported) {
      return Text(
        'Paso no soportado — actualiza la app para verlo.',
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
    // Nombre legible del recurso. Prioridad: el alias EN VIVO del catálogo
    // (resuelto por ref vía MediaNamesCubit, leído por el caller) → el
    // `media_filename` guardado al elegirlo → la cola corta del ref BARE en
    // monospace (señal de id, no nombre). El ref completo con el path del
    // tenant nunca se muestra.
    final (mediaText, mono) = mediaStepDisplay(
      mediaRef: step.mediaRef,
      metadataJson: step.metadataJson,
      resolvedName: resolvedMediaName,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          mediaText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: mono
              ? textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: AppTokens.text2,
                )
              : textTheme.bodyMedium,
        ),
        if (step.content.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppTokens.sp1),
          Text(step.content, style: textTheme.bodyMedium),
        ],
      ],
    );
  }
}

/// Resumen read-only de un paso LABEL en la StepCard: la acción
/// (Etiquetar / Quitar etiqueta) + el NOMBRE de la etiqueta resuelto del
/// catálogo ([labelNames]); el id crudo queda sólo como respaldo honesto
/// (catálogo cargando, fallo o label borrada) y distingue pasos. Metadata
/// inválida ⇒ fallback "sin configurar".
class _LabelStepSummary extends StatelessWidget {
  const _LabelStepSummary({
    required this.step,
    required this.textTheme,
    this.labelNames = const <String, String>{},
  });

  final sdom.Step step;
  final TextTheme textTheme;
  final Map<String, String> labelNames;

  @override
  Widget build(BuildContext context) {
    final LabelStepMetadata md;
    try {
      md = LabelStepMetadata.fromJsonString(step.metadataJson);
    } on FormatException {
      return Text(
        'Etiqueta sin configurar',
        style: textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      );
    }
    final isAdd = md.action == LabelStepAction.add;
    final resolvedName = labelNames[md.labelId];
    return Row(
      children: <Widget>[
        Icon(
          isAdd ? Icons.label_outline : Icons.label_off_outlined,
          size: 16,
          color: AppTokens.text2,
        ),
        const SizedBox(width: AppTokens.sp2),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: <TextSpan>[
                TextSpan(
                  text: isAdd ? 'Etiquetar · ' : 'Quitar etiqueta · ',
                  style: textTheme.bodyMedium,
                ),
                if (resolvedName != null)
                  TextSpan(text: resolvedName, style: textTheme.bodyMedium)
                else
                  TextSpan(
                    text: md.labelId,
                    style: textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: AppTokens.text2,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Resumen read-only del shape CONDITIONAL_TIME en la StepCard. Parsea
/// el metadataJson y formatea: TZ + cada ventana ("L M X J V · 09:00–18:00")
/// + flechas a los pasos destino (`Paso #{order+1}`). Fallback honesto si
/// el metadata es inválido — el operador puede entrar al editor a
/// reconfigurar.
///
/// Nota: `onMatchOrder`/`onElseOrder` son enteros que apuntan a la
/// posición de otro step, no a su id. Al reordenar desde el cliente, el
/// bloc recompone estos destinos para que sigan al paso lógico; pero el
/// wire sigue siendo posicional, así que un reorder fuera de banda (otro
/// cliente, API directa, seed) puede dejarlos apuntando a un paso distinto.
class _ConditionalTimeSummary extends StatelessWidget {
  const _ConditionalTimeSummary({required this.step, required this.textTheme});

  final sdom.Step step;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final ConditionalTimeMetadata md;
    try {
      md = ConditionalTimeMetadata.fromJsonString(step.metadataJson);
    } on FormatException {
      return Text(
        'Condicional con configuración inválida — reabre el paso para corregir.',
        key: const Key('flow_detail.step.ct_corrupt'),
        style: textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.danger,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Zona ${md.tz}',
          style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        for (final w in md.windows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.sp1),
            child: Text(
              '${_formatDays(w.days)} · ${w.from}–${w.to}',
              style: textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: AppTokens.sp1),
        Text(
          'Si cumple → Paso #${md.onMatchOrder + 1}   ·   '
          'Si no → Paso #${md.onElseOrder + 1}',
          style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
        ),
      ],
    );
  }

  String _formatDays(List<int> wireDays) {
    final uiSorted = wireDays.map(wireDayToUi).toList()..sort();
    return uiSorted.map(uiDayLabel).join(' ');
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
