import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../labels/presentation/bloc/labels_bloc.dart';
import '../../../media/domain/entities/media_asset.dart';
import '../../domain/entities/step.dart' as sdom;
import '../../domain/failures/flows_failure.dart';
import '../bloc/flow_steps_bloc.dart';
import '../bloc/media_names_cubit.dart';
import 'step_card.dart';
import 'step_editor_launcher.dart';
import 'step_reorder_rules.dart';

/// Cuerpo principal del hub del editor: la lista de pasos atada al
/// `FlowStepsBloc`, con [header] (identidad excepcional del flujo) por
/// encima y [footer] (launchers a subpáginas + zona peligrosa) al fondo,
/// AMBOS dentro del mismo scroll — la página completa se desplaza como
/// una sola superficie, y con ≥2 pasos ese scroll es el
/// `ReorderableListView` que el drag&drop necesita.
///
/// El footer se monta en TODOS los estados de los pasos: aunque el
/// listado cargue o falle, el operador puede seguir operando el flujo
/// (disparadores, configuración, borrado).
class FlowStepsSection extends StatelessWidget {
  const FlowStepsSection({super.key, this.header, this.footer});

  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FlowStepsBloc, FlowStepsState>(
      // Sólo el reorder muta sin un sheet delante: add/edit/delete reportan
      // su fallo inline dentro del sheet abierto. El gate `isCurrent` evita
      // duplicar el aviso cuando el fallo ocurre con un modal encima.
      listener: (context, state) {
        if (state is FlowStepsMutationFailed &&
            (ModalRoute.of(context)?.isCurrent ?? true)) {
          final copy = state.failure is FlowsInvalidReorderFailure
              ? forwardOnlyReorderCopy
              : 'No se pudo guardar el nuevo orden. Se revirtieron los '
                    'cambios.';
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(copy)));
        }
      },
      builder: (context, state) => switch (state) {
        // Solo la carga inicial (o el retry de un Failed terminal) muestra
        // spinner puro: todavía no hay lista que conservar.
        FlowStepsLoading() => _Static(
          header: header,
          footer: footer,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTokens.sp6),
            child: AppLoadingIndicator(),
          ),
        ),
        FlowStepsLoaded(steps: final ss) => _StepsListView(
          steps: ss,
          header: header,
          footer: footer,
        ),
        // Todo estado con lista la mantiene en pantalla — la mutación en
        // vuelo y el refetch posterior solo agregan el progreso inline;
        // el operador nunca pierde contexto ni scroll.
        FlowStepsMutating(steps: final ss) => _StepsListView(
          steps: ss,
          header: header,
          footer: footer,
          notice: const _MutatingInlineSpinner(),
        ),
        FlowStepsRefreshing(steps: final ss) => _StepsListView(
          steps: ss,
          header: header,
          footer: footer,
          notice: const _MutatingInlineSpinner(),
        ),
        // La mutación persistió pero el listado no se pudo refrescar: la
        // lista visible puede estar desactualizada; el aviso lo dice y
        // ofrece reintentar el refetch conservándola.
        FlowStepsRefreshFailed(steps: final ss) => _StepsListView(
          steps: ss,
          header: header,
          footer: footer,
          notice: const _RefreshFailedNotice(),
        ),
        FlowStepsMutationFailed(steps: final ss) => _StepsListView(
          steps: ss,
          header: header,
          footer: footer,
        ),
        FlowStepsFailed(failure: final f) => _Static(
          header: header,
          footer: footer,
          child: _StepsFailedView(failure: f),
        ),
      },
    );
  }
}

/// Padding común de la superficie scrolleable del hub.
EdgeInsets _pagePadding(BuildContext context) => EdgeInsets.fromLTRB(
  AppTokens.sp6,
  AppTokens.sp6,
  AppTokens.sp6,
  AppTokens.sp6 + context.safeBottomInset,
);

/// Separación entre el final del contenido de pasos y el footer.
Widget _footerBlock(Widget footer) => Padding(
  padding: const EdgeInsets.only(top: AppTokens.sp6),
  child: footer,
);

/// Layout scrolleable simple para los estados sin lista reordenable
/// (carga inicial, fallo terminal): header + contenido + footer.
class _Static extends StatelessWidget {
  const _Static({required this.child, this.header, this.footer});

  final Widget child;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final h = header;
    final f = footer;
    return SingleChildScrollView(
      padding: _pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (h != null) ...<Widget>[h, const SizedBox(height: AppTokens.sp4)],
          child,
          if (f != null) _footerBlock(f),
        ],
      ),
    );
  }
}

/// Renderiza la lista de StepCards o el empty state. `notice` es el aviso
/// inline que el estado del bloc quiera anteponer (progreso de mutación,
/// refetch fallido) SIN tapar la lista existente — nunca un overlay.
///
/// Con ≥2 steps usa `ReorderableListView.builder` (con el header y footer
/// dentro del mismo scroll) para soportar drag&drop. Con 0 o 1 step usa
/// un layout simple — no tiene sentido pagar el costo del scroll de
/// reorder cuando no hay nada que reordenar.
class _StepsListView extends StatelessWidget {
  const _StepsListView({
    required this.steps,
    this.header,
    this.footer,
    this.notice,
  });

  final List<sdom.Step> steps;
  final Widget? header;
  final Widget? footer;
  final Widget? notice;

  /// Encabezado de la sección de pasos: la identidad excepcional que el
  /// hub aporte + el aviso inline + la CTA de alta (solo con pasos; el
  /// vacío ofrece la suya en el empty state).
  List<Widget> _sectionHeader(BuildContext context) {
    final h = header;
    final n = notice;
    return <Widget>[
      if (h != null) ...<Widget>[h, const SizedBox(height: AppTokens.sp4)],
      if (n != null) ...<Widget>[n, const SizedBox(height: AppTokens.sp3)],
      if (steps.isNotEmpty) ...<Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.text(
            key: const Key('flow_detail.steps.add_button'),
            label: 'Nuevo paso',
            icon: Icons.add,
            onPressed: () => openStepSheet(context, null),
          ),
        ),
        const SizedBox(height: AppTokens.sp3),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
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
    // Índice id → (posición, etiqueta) de los steps vigentes, para que la
    // tarjeta del condicional resuelva sus destinos por NOMBRE y marque
    // colgantes/hacia-atrás. Plano y calculado aquí arriba por el mismo
    // motivo overlay-safe que labelNames/mediaNames.
    final stepRefs = <String, ({int order, String label})>{
      for (final s in steps) s.id: (order: s.order, label: stepRefLabel(s)),
    };
    final f = footer;

    if (steps.isEmpty) {
      return _Static(
        header: header,
        footer: footer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (notice != null) ...<Widget>[
              notice!,
              const SizedBox(height: AppTokens.sp3),
            ],
            AppEmptyState(
              key: const Key('flow_detail.steps.empty'),
              icon: Icons.forum_outlined,
              title: 'Este flujo aún no tiene pasos',
              description:
                  'Los pasos son los mensajes y acciones que el flujo '
                  'ejecuta en orden.',
              ctaLabel: 'Crear el primer paso',
              ctaIcon: Icons.add,
              onCta: () => openStepSheet(context, null),
            ),
          ],
        ),
      );
    }

    if (steps.length == 1) {
      return SingleChildScrollView(
        padding: _pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ..._sectionHeader(context),
            StepCard(
              step: steps.first,
              onTap: () => openStepSheet(context, steps.first),
              resolvedMediaName: namesState.nameFor(steps.first.mediaRef),
              labelNames: labelNames,
              stepRefs: stepRefs,
            ),
            if (f != null) _footerBlock(f),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: _pagePadding(context),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _sectionHeader(context),
      ),
      footer: f == null ? null : _footerBlock(f),
      itemCount: steps.length,
      buildDefaultDragHandles: false,
      itemBuilder: (_, i) {
        final s = steps[i];
        return Padding(
          key: ValueKey<String>('flow_detail.step_card.row.${s.id}'),
          padding: const EdgeInsets.only(bottom: AppTokens.sp3),
          child: StepCard(
            step: s,
            dragIndex: i,
            onTap: () => openStepSheet(context, s),
            resolvedMediaName: namesState.nameFor(s.mediaRef),
            labelNames: labelNames,
            stepRefs: stepRefs,
          ),
        );
      },
      onReorderItem: (oldIdx, newIdx) {
        // onReorderItem entrega newIdx ya ajustado sin el elemento movido.
        final reordered = List<sdom.Step>.of(steps);
        reordered.insert(newIdx, reordered.removeAt(oldIdx));
        // Forward-only se previene ANTES del request: el drop inválido no
        // se dispatcha (estado igual ⇒ la lista rebota); backend = red final.
        if (!conditionalTargetsStayForward(reordered)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text(forwardOnlyReorderCopy)),
            );
          return;
        }
        bloc.add(
          FlowStepsReorderRequested(<String>[for (final s in reordered) s.id]),
        );
      },
    );
  }
}

/// Abre el editor de pasos en dos tiempos: sin `step`, primero el selector
/// de tipo y luego la composición del tipo elegido (cancelar el selector no
/// abre nada); con `step`, directo a la composición en modo edición. Lo usan
/// la CTA de alta (botón / empty state) y el tap de cada card.
/// `openStepEditor` re-provee los blocs del scope y aplica el fondo canónico.
///
/// Al crear o reemplazar el recurso de un step multimedia, el selector abre
/// la galería en modo picker (`/media/pick?type=<familia>`, filtrada por el
/// tipo del paso) que devuelve el MediaAsset completo vía pop.
void openStepSheet(BuildContext context, sdom.Step? step) {
  openStepEditor(
    context,
    editing: step,
    pickMediaRef: (ctx, family) => ctx.push<MediaAsset>(
      family == null ? '/media/pick' : '/media/pick?type=$family',
    ),
  );
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

/// Aviso inline de refetch fallido tras una mutación que SÍ persistió:
/// la lista en pantalla puede estar desactualizada, y Reintentar vuelve
/// a pedir el listado conservándola (RefreshRequested — nunca Loading).
class _RefreshFailedNotice extends StatelessWidget {
  const _RefreshFailedNotice();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      key: const Key('flow_detail.steps.refresh_failed'),
      children: <Widget>[
        Expanded(
          child: Text(
            'El cambio se guardó, pero no pudimos actualizar la lista.',
            style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
          ),
        ),
        const SizedBox(width: AppTokens.sp3),
        AppButton.tonal(
          key: const Key('flow_detail.steps.refresh_retry'),
          label: 'Reintentar',
          onPressed: () => context.read<FlowStepsBloc>().add(
            const FlowStepsRefreshRequested(),
          ),
        ),
      ],
    );
  }
}

class _StepsFailedView extends StatelessWidget {
  const _StepsFailedView({required this.failure});

  final FlowsFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is FlowsNotFoundFailure;
    // NotFound es terminal: recargar no lo revive, así que no hay reintento.
    return AppErrorState(
      key: isNotFound
          ? const Key('flow_detail.steps.error.not_found')
          : const Key('flow_detail.steps.error.generic'),
      message: isNotFound
          ? 'No pudimos encontrar los pasos de este flujo'
          : 'No pudimos cargar los pasos',
      onRetry: isNotFound
          ? null
          : () => context.read<FlowStepsBloc>().add(
              const FlowStepsLoadRequested(),
            ),
    );
  }
}
