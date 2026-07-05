import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_step_timeline.dart';
import '../../../../core/design/widgets/app_timeline_row.dart';
import '../../../labels/presentation/bloc/labels_bloc.dart';
import '../../../media/domain/entities/media_asset.dart';
import '../../domain/entities/step.dart' as sdom;
import '../bloc/flow_steps_bloc.dart';
import '../bloc/media_names_cubit.dart';
import 'step_editor_launcher.dart';
import 'step_reorder_rules.dart';
import 'step_row.dart';
import 'step_timeline_jumps.dart';

/// Padding común de la superficie scrolleable del hub de pasos.
EdgeInsets stepsPagePadding(BuildContext context) => EdgeInsets.fromLTRB(
  AppTokens.sp6,
  AppTokens.sp6,
  AppTokens.sp6,
  AppTokens.sp6 + context.safeBottomInset,
);

/// Separación entre el final del contenido de pasos y el footer del hub.
Widget stepsFooterBlock(Widget footer) => Padding(
  padding: const EdgeInsets.only(top: AppTokens.sp6),
  child: footer,
);

/// Abre el editor de pasos en dos tiempos: sin `step`, primero el selector
/// de tipo y luego la composición del tipo elegido (cancelar el selector no
/// abre nada); con `step`, directo a la composición en modo edición. Lo usan
/// la CTA del empty state, el inserter del timeline y el tap de cada fila.
/// `openStepEditor` re-provee los blocs del scope y aplica el fondo canónico.
///
/// [insertOrder] llega del "+" del timeline: la posición que ocupará el
/// paso nuevo (el backend desplaza los siguientes); null = append.
///
/// Al crear o reemplazar el recurso de un step multimedia, el selector abre
/// la galería en modo picker (`/media/pick?type=<familia>`, filtrada por el
/// tipo del paso) que devuelve el MediaAsset completo vía pop.
void openStepSheet(BuildContext context, sdom.Step? step, {int? insertOrder}) {
  openStepEditor(
    context,
    editing: step,
    insertOrder: insertOrder,
    pickMediaRef: (ctx, family) => ctx.push<MediaAsset>(
      family == null ? '/media/pick' : '/media/pick?type=$family',
    ),
  );
}

/// El timeline de pasos del editor: filas de `StepRow` dentro de un
/// `AppStepTimeline` — índice + espina + saltos de rama derivados de los
/// condicionales, reorder validado ANTES del drop con la regla
/// forward-only existente, e inserción posicional con el "+" entre filas.
///
/// Presentación pura: el estado de revelado (highlight + scroll-to del
/// paso recién creado) vive en la sección — aquí solo se pinta.
class StepsTimelineView extends StatelessWidget {
  const StepsTimelineView({
    super.key,
    required this.steps,
    required this.rowKeys,
    this.controller,
    this.highlightId,
    this.header,
    this.footer,
  });

  final List<sdom.Step> steps;

  /// Identidad ESTABLE por step id, provista por la sección: además de
  /// key de item del reorder, es cómo la sección localiza la fila del
  /// paso recién creado para el scroll-to.
  final Map<String, GlobalKey> rowKeys;

  final ScrollController? controller;

  /// Id del paso a anunciar con el glow one-shot (recién creado).
  final String? highlightId;

  /// Contenido por ENCIMA del timeline (identidad del hub + avisos).
  final Widget? header;

  /// Contenido al fondo del scroll (launchers + zona peligrosa).
  final Widget? footer;

  /// Orden propuesto tras mover la fila [from] a la posición [to].
  List<sdom.Step> _proposed(int from, int to) {
    final reordered = List<sdom.Step>.of(steps);
    reordered.insert(to, reordered.removeAt(from));
    return reordered;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<FlowStepsBloc>();
    // Resuelve los nombres EN VIVO del catálogo UNA vez, POR ENCIMA del
    // timeline, y se los pasa a cada fila como dato plano. Si el lookup
    // del cubit viviera dentro del item reordenable, al arrastrarlo el
    // item se eleva al overlay del Navigator (fuera del scope del
    // provider) y el lookup lanzaría ProviderNotFound.
    final namesState = context.watch<MediaNamesCubit>().state;
    // Mismo patrón para el catálogo de labels: mapa plano id→nombre para
    // que el paso LABEL muestre el nombre y no el UUID.
    final labelsState = context.watch<LabelsBloc>().state;
    final labelNames = labelsState is LabelsLoaded
        ? <String, String>{for (final l in labelsState.labels) l.id: l.name}
        : const <String, String>{};
    // Índice id → (posición, etiqueta) de los steps vigentes, para que el
    // resumen del condicional resuelva sus destinos por NOMBRE y marque
    // colgantes/hacia-atrás. Plano y calculado aquí arriba por el mismo
    // motivo overlay-safe que labelNames/mediaNames.
    final stepRefs = <String, ({int order, String label})>{
      for (final s in steps) s.id: (order: s.order, label: stepRefLabel(s)),
    };
    final canDrag = steps.length >= 2;

    return AppStepTimeline(
      controller: controller,
      padding: stepsPagePadding(context),
      header: header,
      footer: footer,
      itemCount: steps.length,
      itemKey: (i) => rowKeys.putIfAbsent(steps[i].id, GlobalKey.new),
      jumps: stepTimelineJumps(steps),
      // El inserter del final conserva la key histórica de la CTA de alta:
      // misma superficie ("agregar paso"), nueva forma.
      insertEndKey: const Key('flow_detail.steps.add_button'),
      insertEndLabel: 'Agregar paso',
      onInsertAt: (i) => openStepSheet(context, null, insertOrder: i),
      // Forward-only se previene ANTES del drop: el veto deja la fila
      // rebotar sin round-trip y avisa localmente; backend = red final.
      canReorder: (from, to) {
        if (conditionalTargetsStayForward(_proposed(from, to))) return true;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text(forwardOnlyReorderCopy)));
        return false;
      },
      onReorder: (from, to) => bloc.add(
        FlowStepsReorderRequested(<String>[
          for (final s in _proposed(from, to)) s.id,
        ]),
      ),
      itemBuilder: (context, i) {
        final s = steps[i];
        return AppTimelineRow(
          index: i,
          spineAbove: i > 0,
          spineBelow: i < steps.length - 1,
          dragIndex: canDrag ? i : null,
          dragHandleKey: Key('flow_detail.step_card.drag_handle.${s.id}'),
          highlighted: s.id == highlightId,
          child: StepRow(
            step: s,
            onTap: () => openStepSheet(context, s),
            resolvedMediaName: namesState.nameFor(s.mediaRef),
            labelNames: labelNames,
            stepRefs: stepRefs,
          ),
        );
      },
    );
  }
}
