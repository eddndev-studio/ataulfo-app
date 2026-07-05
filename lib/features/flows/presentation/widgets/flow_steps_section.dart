import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../domain/entities/step.dart' as sdom;
import '../../domain/failures/flows_failure.dart';
import '../bloc/flow_steps_bloc.dart';
import 'step_reorder_rules.dart';
import 'step_timeline_view.dart';

/// Cuerpo principal del hub del editor: el timeline de pasos atado al
/// `FlowStepsBloc`, con [header] (identidad excepcional del flujo) por
/// encima y [footer] (launchers a subpáginas + zona peligrosa) al fondo,
/// AMBOS dentro del mismo scroll — la página completa se desplaza como
/// una sola superficie, y con ≥2 pasos ese scroll es el del timeline
/// reordenable.
///
/// El footer se monta en TODOS los estados de los pasos: aunque el
/// listado cargue o falle, el operador puede seguir operando el flujo
/// (disparadores, configuración, borrado).
///
/// La sección además ANUNCIA el paso recién creado/insertado: detecta el
/// id nuevo al llegar el listado refrescado, hace scroll hasta su fila y
/// la enciende con el glow one-shot del timeline — con inserción a media
/// lista, el paso ya no aparece sin aviso.
class FlowStepsSection extends StatefulWidget {
  const FlowStepsSection({super.key, this.header, this.footer});

  final Widget? header;
  final Widget? footer;

  @override
  State<FlowStepsSection> createState() => _FlowStepsSectionState();
}

class _FlowStepsSectionState extends State<FlowStepsSection> {
  final ScrollController _scroll = ScrollController();

  /// Identidad estable por step id: key de item del timeline Y ancla del
  /// scroll-to (su `currentContext` localiza la fila ya construida).
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};

  /// Ids del último listado CONFIRMADO (Loaded); contra ellos se detecta
  /// el paso recién creado. Null hasta el primer listado.
  List<String>? _knownIds;

  /// Paso a anunciar (highlight one-shot). Persiste hasta el siguiente
  /// anuncio: el glow del timeline solo re-anima en la transición.
  String? _highlightId;

  @override
  void initState() {
    super.initState();
    // La sección puede montarse con el listado ya cargado (regreso de una
    // subpágina): ese snapshot es la línea base, no un lote "nuevo".
    final state = context.read<FlowStepsBloc>().state;
    if (state is FlowStepsLoaded) {
      _knownIds = <String>[for (final s in state.steps) s.id];
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Detecta el paso recién creado comparando el Loaded entrante contra el
  /// último listado conocido: EXACTAMENTE un id nuevo = un alta que
  /// anunciar (reorder/edición conservan ids; el refetch inicial no tiene
  /// baseline). Corre en el listener del consumer — antes del rebuild, así
  /// el highlight ya viaja en ese mismo frame.
  void _trackNewStep(FlowStepsState state) {
    if (state is! FlowStepsLoaded) return;
    final ids = <String>[for (final s in state.steps) s.id];
    final known = _knownIds;
    _knownIds = ids;
    _rowKeys.removeWhere((id, _) => !ids.contains(id));
    if (known == null) return;
    final added = <String>[
      for (final id in ids)
        if (!known.contains(id)) id,
    ];
    if (added.length != 1) return;
    _highlightId = added.single;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealStep(added.single);
    });
  }

  /// Scroll hasta la fila del paso [id]. Si la fila aún no se construyó
  /// (lista larga, alta al final), se acerca al extremo y reintenta una
  /// vez ya con el item en el viewport.
  void _revealStep(String id) {
    final ctx = _rowKeys[id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: AppTokens.durationSlow,
        curve: AppTokens.ease,
      );
      return;
    }
    if (!_scroll.hasClients) return;
    _scroll
        .animateTo(
          _scroll.position.maxScrollExtent,
          duration: AppTokens.durationSlow,
          curve: AppTokens.ease,
        )
        .then((_) {
          if (!mounted) return;
          final lateCtx = _rowKeys[id]?.currentContext;
          if (lateCtx == null || !lateCtx.mounted) return;
          Scrollable.ensureVisible(
            lateCtx,
            alignment: 0.35,
            duration: AppTokens.durationFast,
            curve: AppTokens.ease,
          );
        });
  }

  /// Timeline con lista o empty state, según haya pasos. `notice` es el
  /// aviso inline que el estado del bloc quiera anteponer (progreso de
  /// mutación, refetch fallido) SIN tapar la lista — nunca un overlay.
  Widget _listOrEmpty(List<sdom.Step> steps, {Widget? notice}) {
    if (steps.isEmpty) {
      return _Static(
        header: widget.header,
        footer: widget.footer,
        notice: notice,
        child: AppEmptyState(
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
      );
    }
    final h = widget.header;
    final n = notice;
    return StepsTimelineView(
      steps: steps,
      rowKeys: _rowKeys,
      controller: _scroll,
      highlightId: _highlightId,
      header: (h == null && n == null)
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (h != null) ...<Widget>[
                  h,
                  const SizedBox(height: AppTokens.sp4),
                ],
                if (n != null) ...<Widget>[
                  n,
                  const SizedBox(height: AppTokens.sp3),
                ],
              ],
            ),
      footer: widget.footer == null ? null : stepsFooterBlock(widget.footer!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FlowStepsBloc, FlowStepsState>(
      // Sólo el reorder muta sin un sheet delante: add/edit/delete reportan
      // su fallo inline dentro del sheet abierto. El gate `isCurrent` evita
      // duplicar el aviso cuando el fallo ocurre con un modal encima.
      listener: (context, state) {
        _trackNewStep(state);
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
          header: widget.header,
          footer: widget.footer,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTokens.sp6),
            child: AppLoadingIndicator(),
          ),
        ),
        FlowStepsLoaded(steps: final ss) => _listOrEmpty(ss),
        // Todo estado con lista la mantiene en pantalla — la mutación en
        // vuelo y el refetch posterior solo agregan el progreso inline;
        // el operador nunca pierde contexto ni scroll.
        FlowStepsMutating(steps: final ss) => _listOrEmpty(
          ss,
          notice: const _MutatingInlineSpinner(),
        ),
        FlowStepsRefreshing(steps: final ss) => _listOrEmpty(
          ss,
          notice: const _MutatingInlineSpinner(),
        ),
        // La mutación persistió pero el listado no se pudo refrescar: la
        // lista visible puede estar desactualizada; el aviso lo dice y
        // ofrece reintentar el refetch conservándola.
        FlowStepsRefreshFailed(steps: final ss) => _listOrEmpty(
          ss,
          notice: const _RefreshFailedNotice(),
        ),
        FlowStepsMutationFailed(steps: final ss) => _listOrEmpty(ss),
        FlowStepsFailed(failure: final f) => _Static(
          header: widget.header,
          footer: widget.footer,
          child: _StepsFailedView(failure: f),
        ),
      },
    );
  }
}

/// Layout scrolleable simple para los estados sin timeline (carga
/// inicial, fallo terminal, flujo sin pasos): header + aviso + contenido
/// + footer.
class _Static extends StatelessWidget {
  const _Static({required this.child, this.header, this.footer, this.notice});

  final Widget child;
  final Widget? header;
  final Widget? footer;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final h = header;
    final n = notice;
    final f = footer;
    return SingleChildScrollView(
      padding: stepsPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (h != null) ...<Widget>[h, const SizedBox(height: AppTokens.sp4)],
          if (n != null) ...<Widget>[n, const SizedBox(height: AppTokens.sp3)],
          child,
          if (f != null) stepsFooterBlock(f),
        ],
      ),
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
