// Pesa >400 LOC porque agrupa el shell del listado de Plantillas (header, CTA
// de creación, buscador, filtros, tile con badge IA + métricas, y los estados
// vacío/carga/error) con sus helpers cohesivos. Los widgets viven solo aquí; un
// split compartiría estructuras privadas entre archivos hermanos sin reuso
// real. Si crece más, el primer corte es extraer _TemplateTile + _MetricsRow a
// `widgets/template_tile.dart`.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_header_card.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_dot_label.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/provider_badge.dart';
import '../../../../core/util/user_greeting.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/template.dart';
import '../bloc/templates_bloc.dart';
import '../widgets/template_create_sheet.dart';

/// Filtro por presencia de IA. Estado de UI local (client-side sobre la lista
/// ya cargada), no del bloc: el backend devuelve todas las plantillas y el
/// operador acota la vista sin round-trip.
enum _TemplateFilter { all, withAi, withoutAi }

/// Listado de Asistentes sobre el modelo interno Template. Consume el
/// TemplatesBloc del scope; el cableado
/// del provider lo hace el shell. Es content-only: el Scaffold, el AppBar (que
/// titula "Plantillas") y el FAB de creación los aporta el ShellPage — la
/// card-CTA de esta page comparte ese destino `/templates/new`.
///
/// Si recibe un `routeObserver`, se suscribe como `RouteAware` y dispara
/// `TemplatesRefreshRequested` cuando una sub-ruta (create/edit) vuelve al
/// stack tras un pop. Sin observer la page funciona idéntico — composición
/// opcional, no contrato obligatorio.
class TemplatesListPage extends StatefulWidget {
  const TemplatesListPage({super.key, this.routeObserver, this.onOpenSettings});

  final RouteObserver<PageRoute<dynamic>>? routeObserver;

  /// Acción del avatar del header → abrir Ajustes. La aporta el shell.
  final VoidCallback? onOpenSettings;

  @override
  State<TemplatesListPage> createState() => _TemplatesListPageState();
}

class _TemplatesListPageState extends State<TemplatesListPage> with RouteAware {
  late final TextEditingController _searchCtrl;
  _TemplateFilter _filter = _TemplateFilter.all;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final observer = widget.routeObserver;
    if (observer == null) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute) observer.subscribe(this, route);
  }

  @override
  void dispose() {
    widget.routeObserver?.unsubscribe(this);
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Una sub-ruta (e.g. /templates/new, /templates/:id, /templates/:id/edit)
    // popeó y este listado vuelve al foreground. Refetch transparente alinea el
    // bloc con la verdad del backend sin pull-to-refresh manual.
    context.read<TemplatesBloc>().add(const TemplatesRefreshRequested());
  }

  /// Aplica búsqueda (nombre) + filtro de IA a la lista cargada.
  List<Template> _applyFilters(List<Template> items) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return items.where((t) {
      final matchesQuery = q.isEmpty || t.name.toLowerCase().contains(q);
      final matchesFilter = switch (_filter) {
        _TemplateFilter.all => true,
        _TemplateFilter.withAi => t.ai.enabled,
        _TemplateFilter.withoutAi => !t.ai.enabled,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<TemplatesBloc>();
    bloc.add(const TemplatesRefreshRequested());
    // Espera a que el bloc deje el estado refreshing (o caiga a Failed) para que
    // el RefreshIndicator no quite el spinner antes de tiempo.
    await bloc.stream.firstWhere(
      (s) => (s is TemplatesLoaded && !s.isRefreshing) || s is TemplatesFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TemplatesBloc, TemplatesState>(
      builder: (context, state) => switch (state) {
        TemplatesInitial() || TemplatesLoading() => const _LoadingView(),
        TemplatesLoaded(items: final items) =>
          items.isEmpty
              ? _EmptyView(onRefresh: () => _refresh(context))
              : _buildLoaded(context, items),
        TemplatesFailed() => const _FailedView(),
      },
    );
  }

  String _emailFromSession(BuildContext context) {
    final state = context.read<AuthBloc>().state;
    return switch (state) {
      AuthAuthenticated(:final identity) => identity.email,
      AuthAuthenticatedNoOrg(:final identity) => identity.email,
      _ => '',
    };
  }

  Widget _buildLoaded(BuildContext context, List<Template> items) {
    final filtered = _applyFilters(items);
    final user = userGreeting(_emailFromSession(context));
    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Sin padding aquí: el header es full-bleed y va pegado arriba.
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppHeaderCard(
              greeting: user.greeting,
              title: 'Asistentes',
              avatarInitial: user.initial,
              onAvatarTap: widget.onOpenSettings ?? () {},
              watermark: Icons.support_agent,
            ),
            Padding(
              key: const Key('templates.content_padding'),
              padding: EdgeInsets.fromLTRB(
                AppTokens.sp5,
                AppTokens.sp5,
                AppTokens.sp5,
                // fabClearance: la última fila debe poder quedar por encima
                // del FAB de crear que flota sobre esta tab.
                AppTokens.fabClearance + context.safeBottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SearchField(controller: _searchCtrl),
                  const SizedBox(height: AppTokens.sp4),
                  _FilterChips(
                    selected: _filter,
                    onSelected: (f) => setState(() => _filter = f),
                  ),
                  const SizedBox(height: AppTokens.sp5),
                  if (filtered.isEmpty)
                    const _NoResults()
                  else
                    _TemplatesCard(templates: filtered),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Buscador del listado: filtra por nombre (client-side).
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      key: const Key('templates.search'),
      label: 'Buscar Asistente',
      hint: 'Nombre',
      controller: controller,
    );
  }
}

/// Fila de filtros por IA. Selección única — al tocar un chip se fija ese filtro
/// (ignora el bool de `onSelected`).
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final _TemplateFilter selected;
  final ValueChanged<_TemplateFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTokens.sp2,
      runSpacing: AppTokens.sp2,
      children: <Widget>[
        _chip('Todas', _TemplateFilter.all, 'all'),
        _chip('Con IA', _TemplateFilter.withAi, 'with_ai'),
        _chip('Sin IA', _TemplateFilter.withoutAi, 'without_ai'),
      ],
    );
  }

  Widget _chip(String label, _TemplateFilter value, String id) => AppChoiceChip(
    key: Key('templates.filter.$id'),
    label: label,
    selected: selected == value,
    onSelected: (_) => onSelected(value),
  );
}

/// El listado como UNA card que apila las filas de plantillas separadas por
/// divider hairline (idioma de los hubs y de ajustes), en lugar de una card
/// suelta por item.
class _TemplatesCard extends StatelessWidget {
  const _TemplatesCard({required this.templates});

  final List<Template> templates;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < templates.length; i++) {
      if (i > 0) {
        rows.add(
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
        );
      }
      rows.add(_TemplateTile(template: templates[i]));
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}

/// Fila de una plantilla dentro de la card del listado: glifo de entidad +
/// nombre con las métricas (bots/flujos/variables) como caption debajo, y a la
/// derecha el estado de IA quieto. Toda la fila es tap-target hacia el detalle;
/// el InkWell propio da el ripple (la card contenedora no es tappable).
class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final counts = template.counts;
    return InkWell(
      key: Key('templates.tile.${template.id}'),
      // push (no go): el detalle se apila sobre el listado para que el back
      // físico y la flecha del AppBar vuelvan al shell con la tab Plantillas.
      onTap: () => context.push('/assistants/${template.id}'),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
        child: Row(
          children: <Widget>[
            const AppEntityIcon(icon: Icons.support_agent_outlined),
            const SizedBox(width: AppTokens.sp4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    template.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  // counts == null ⇒ respuesta sin enriquecer (no es el
                  // listado): se omite la fila. Counts en cero SÍ se muestran.
                  if (counts != null) ...<Widget>[
                    const SizedBox(height: AppTokens.sp1),
                    _MetricsRow(templateId: template.id, counts: counts),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppTokens.sp3),
            _AiBadge(ai: template.ai),
          ],
        ),
      ),
    );
  }
}

/// Estado de IA de la plantilla como indicador quieto: encendida → dot success
/// + proveedor ("IA · OpenAI"); apagada → "Sin IA" con dot neutro. El color
/// vive solo en el dot — repetido por fila, un pill por plantilla sería ruido.
class _AiBadge extends StatelessWidget {
  const _AiBadge({required this.ai});

  final AIConfig ai;

  @override
  Widget build(BuildContext context) {
    if (!ai.enabled) {
      return const AppDotLabel(color: AppTokens.text2, label: 'Sin IA');
    }
    return AppDotLabel(
      color: AppTokens.success,
      label: 'IA · ${ProviderBadge.labelOf(ai.provider)}',
    );
  }
}

/// Fila de métricas de la plantilla: bots, flujos y variables. Cada métrica es
/// un ícono + el conteo pluralizado, en caption discreto. Wrap para no
/// desbordar en pantallas estrechas.
class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.templateId, required this.counts});

  final String templateId;
  final TemplateCounts counts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: Key('templates.metrics.$templateId'),
      spacing: AppTokens.sp4,
      runSpacing: AppTokens.sp2,
      children: <Widget>[
        _Metric(
          icon: Icons.smart_toy_outlined,
          label: _plural(counts.bots, 'canal', 'canales'),
        ),
        _Metric(
          icon: Icons.account_tree_outlined,
          label: _plural(counts.flows, 'flujo', 'flujos'),
        ),
        _Metric(
          icon: Icons.data_object,
          label: _plural(counts.variables, 'variable', 'variables'),
        ),
      ],
    );
  }

  static String _plural(int n, String singular, String plural) =>
      '$n ${n == 1 ? singular : plural}';
}

/// Métrica individual: ícono pequeño + texto, en text2. Decorativa-informativa;
/// el texto ya verbaliza el conteo, así que el ícono se excluye de semántica.
class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(child: Icon(icon, size: 16, color: AppTokens.text2)),
        const SizedBox(width: AppTokens.sp1),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
        ),
      ],
    );
  }
}

/// La búsqueda/filtro no dejó plantillas visibles (pero sí las hay en la org).
class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const Key('templates.no_results'),
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp6),
      child: Center(
        child: Text(
          'Ningún Asistente coincide con tu búsqueda o filtro.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) =>
      const AppLoadingIndicator(label: 'Cargando Asistentes…');
}

/// Estado vacío (cero plantillas): card glass centrada que ES el CTA de
/// creación. Scrollable para conservar el pull-to-refresh sobre el vacío.
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.sp5),
              child: Center(
                child: AppEmptyState(
                  key: const Key('templates.empty'),
                  icon: Icons.support_agent_outlined,
                  title: 'Aún no tienes Asistentes',
                  description:
                      'Crea tu primer Asistente, define cómo trabaja y después '
                      'conéctalo a uno o varios canales.',
                  ctaLabel: 'Crear Asistente',
                  ctaIcon: Icons.add,
                  onCta: () async {
                    final template = await TemplateCreateSheet.open(context);
                    if (template != null && context.mounted) {
                      unawaited(context.push('/assistants/${template.id}'));
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado de error de carga: card con mensaje + reintento (no toda roja).
class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp5),
        child: AppErrorState(
          key: const Key('templates.error'),
          message: 'No se pudieron cargar los Asistentes',
          description: 'Revisa tu conexión o intenta nuevamente.',
          onRetry: () =>
              context.read<TemplatesBloc>().add(const TemplatesLoadRequested()),
        ),
      ),
    );
  }
}
