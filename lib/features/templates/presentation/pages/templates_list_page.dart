// Pesa >400 LOC porque agrupa el shell del listado de Plantillas (header, CTA
// de creación, buscador, filtros, tile con badge IA + métricas, y los estados
// vacío/carga/error) con sus helpers cohesivos. Los widgets viven solo aquí; un
// split compartiría estructuras privadas entre archivos hermanos sin reuso
// real. Si crece más, el primer corte es extraer _TemplateTile + _MetricsRow a
// `widgets/template_tile.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/provider_badge.dart';
import '../../domain/entities/template.dart';
import '../bloc/templates_bloc.dart';

/// Filtro por presencia de IA. Estado de UI local (client-side sobre la lista
/// ya cargada), no del bloc: el backend devuelve todas las plantillas y el
/// operador acota la vista sin round-trip.
enum _TemplateFilter { all, withAi, withoutAi }

/// Listado de Plantillas (S03). Consume el TemplatesBloc del scope; el cableado
/// del provider lo hace el shell. Es content-only: el Scaffold, el AppBar (que
/// titula "Plantillas") y el FAB de creación los aporta el ShellPage — la
/// card-CTA de esta page comparte ese destino `/templates/new`.
///
/// Si recibe un `routeObserver`, se suscribe como `RouteAware` y dispara
/// `TemplatesRefreshRequested` cuando una sub-ruta (create/edit) vuelve al
/// stack tras un pop. Sin observer la page funciona idéntico — composición
/// opcional, no contrato obligatorio.
class TemplatesListPage extends StatefulWidget {
  const TemplatesListPage({super.key, this.routeObserver});

  final RouteObserver<PageRoute<dynamic>>? routeObserver;

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

  Widget _buildLoaded(BuildContext context, List<Template> items) {
    final filtered = _applyFilters(items);
    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp5,
          AppTokens.sp5,
          AppTokens.sp5,
          AppTokens.sp5 + context.safeBottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _Header(),
            const SizedBox(height: AppTokens.sp5),
            _CreateTemplateCard(onTap: () => context.push('/templates/new')),
            const SizedBox(height: AppTokens.sp5),
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
              for (final template in filtered) ...<Widget>[
                _TemplateTile(template: template),
                const SizedBox(height: AppTokens.cardGap),
              ],
          ],
        ),
      ),
    );
  }
}

/// Lead descriptivo de la pantalla. El AppBar del shell ya titula "Plantillas",
/// así que aquí NO se repite el título (evita la redundancia de interfaz).
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Text(
      'Define el comportamiento que tus bots heredan: IA, flujos y variables.',
      key: const Key('templates.header'),
      style: textTheme.bodyLarge?.copyWith(color: AppTokens.text2),
    );
  }
}

/// CTA principal: la única card con gradiente de marca. Toda la card es UN
/// botón tappable → `/templates/new` (mismo destino que el FAB del shell). La
/// estructura —ícono-botón a la izquierda, título + descripción al centro,
/// chevron a la derecha— hace que se lea como un botón pleno, no como una card
/// con una pastilla de acción suelta dentro. La marca de agua es un glifo
/// decorativo a la derecha, recortado por el borde.
class _CreateTemplateCard extends StatelessWidget {
  const _CreateTemplateCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard.gradient(
      key: const Key('templates.create_cta'),
      onTap: onTap,
      // padding 0: el padding real lo pone la fila; la marca de agua debe poder
      // sangrar hasta los bordes de la card antes del recorte.
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              bottom: 0,
              right: -28,
              child: ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.fitHeight,
                  child: Icon(
                    Icons.description,
                    color: AppTokens.onPrimary.withValues(alpha: 0.14),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTokens.cardPadding),
              child: Row(
                children: <Widget>[
                  const _CtaIconButton(),
                  const SizedBox(width: AppTokens.sp4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Nueva plantilla',
                          style: textTheme.titleMedium?.copyWith(
                            color: AppTokens.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppTokens.sp1),
                        Text(
                          'Crea una plantilla desde cero y define el '
                          'comportamiento.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTokens.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.sp3),
                  const Icon(Icons.chevron_right, color: AppTokens.onPrimary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ícono-botón cuadrado de la card-CTA: cuadrado oscuro (`onPrimary`) con un
/// "+" en ámbar. Es el ancla visual que comunica "toda la card es un botón".
/// Decorativo (la card ya porta la semántica de acción).
class _CtaIconButton extends StatelessWidget {
  const _CtaIconButton();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTokens.onPrimary,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: const Icon(Icons.add, color: AppTokens.primary, size: 26),
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
      label: 'Buscar plantilla',
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

/// Card tappable de una plantilla. Glifo de entidad + nombre + badge IA arriba;
/// fila de métricas (bots/flujos/variables) abajo cuando el listado las trae.
class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final counts = template.counts;
    return AppCard(
      key: Key('templates.tile.${template.id}'),
      // push (no go): el detalle se apila sobre el listado para que el back
      // físico y la flecha del AppBar vuelvan al shell con la tab Plantillas.
      onTap: () => context.push('/templates/${template.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const AppEntityIcon(icon: Icons.description_outlined),
              const SizedBox(width: AppTokens.sp4),
              Expanded(
                child: Text(
                  template.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: AppTokens.sp3),
              _AiBadge(ai: template.ai),
            ],
          ),
          // counts == null ⇒ respuesta sin enriquecer (no es el listado): se
          // omite la fila entera. counts en cero SÍ se muestran (honesto).
          if (counts != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp4),
            _MetricsRow(templateId: template.id, counts: counts),
          ],
        ],
      ),
    );
  }
}

/// Badge de IA de la plantilla. Encendida → pill neutral con dot activo y el
/// proveedor ("IA · OpenAI"). Apagada → pill outline "Sin IA". Mismo lenguaje
/// discreto que el pill de estado de los bots: el dot cálido basta.
class _AiBadge extends StatelessWidget {
  const _AiBadge({required this.ai});

  final AIConfig ai;

  @override
  Widget build(BuildContext context) {
    if (!ai.enabled) {
      return const AppPill.outline(label: 'Sin IA');
    }
    return AppPill.neutral(
      label: 'IA · ${ProviderBadge.labelOf(ai.provider)}',
      dot: AppPillDot.active,
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
          label: _plural(counts.bots, 'bot', 'bots'),
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
          'Ninguna plantilla coincide con tu búsqueda o filtro.',
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
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
          ),
          const SizedBox(height: AppTokens.sp3),
          Text(
            'Cargando plantillas…',
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío (cero plantillas): card glass centrada que ES el CTA de
/// creación. Scrollable para conservar el pull-to-refresh sobre el vacío.
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
                child: AppCard.glass(
                  key: const Key('templates.empty'),
                  padding: const EdgeInsets.all(AppTokens.cardPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      const AppEntityIcon(
                        icon: Icons.description_outlined,
                        size: 56,
                        highlighted: true,
                      ),
                      const SizedBox(height: AppTokens.sp4),
                      Text(
                        'Aún no tienes plantillas',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppTokens.sp2),
                      Text(
                        'Crea tu primera plantilla para definir el '
                        'comportamiento que heredarán tus bots.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppTokens.text2,
                        ),
                      ),
                      const SizedBox(height: AppTokens.sp5),
                      AppButton.filled(
                        label: 'Crear plantilla',
                        icon: Icons.add,
                        fullWidth: true,
                        onPressed: () => context.push('/templates/new'),
                      ),
                    ],
                  ),
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
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp5),
        child: AppCard(
          key: const Key('templates.error'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'No se pudieron cargar las plantillas',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: AppTokens.sp2),
              Text(
                'Revisa tu conexión o intenta nuevamente.',
                style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              ),
              const SizedBox(height: AppTokens.sp4),
              AppButton.tonal(
                label: 'Reintentar',
                onPressed: () => context.read<TemplatesBloc>().add(
                  const TemplatesLoadRequested(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
