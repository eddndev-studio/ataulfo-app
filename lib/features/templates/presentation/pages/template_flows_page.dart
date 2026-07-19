import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../flows/domain/entities/flow.dart' as fdom;
import '../../../flows/presentation/bloc/flows_bloc.dart';
import '../../../flows/presentation/widgets/flow_create_sheet.dart';
import '../../../triggers/presentation/bloc/triggers_bloc.dart';

/// Lista de flujos de una plantilla (`/templates/:id/flows`), con buscador
/// local y lista densa: UNA card apila las filas (una por flujo) separadas
/// por divider hairline, y cada fila resume sus disparadores y gates
/// (enfriamiento, límite de uso) sin entrar al editor. Posee su Scaffold —
/// AppBar y FAB [+] de crear — como las páginas del entrenador; la ruta
/// solo provee blocs (FlowsBloc + TriggersBloc del template).
class TemplateFlowsPage extends StatefulWidget {
  const TemplateFlowsPage({super.key, required this.templateId});

  final String templateId;

  @override
  State<TemplateFlowsPage> createState() => _TemplateFlowsPageState();
}

class _TemplateFlowsPageState extends State<TemplateFlowsPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // El filtro es derivado del controller: un listener + setState basta,
    // la lista completa ya vive en memoria (no hay query al backend).
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _query => _search.text.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flujos')),
      floatingActionButton: FloatingActionButton(
        key: const Key('template_flows.fab'),
        tooltip: 'Nuevo flujo',
        // El alta vive en un form-sheet sobre esta lista; al crear se apila
        // el editor del flujo nuevo (back físico vuelve aquí y la lista se
        // refresca para mostrarlo con lo que el editor haya cambiado).
        onPressed: () async {
          final flow = await FlowCreateSheet.open(
            context,
            templateId: widget.templateId,
          );
          if (flow == null || !context.mounted) return;
          final flowsBloc = context.read<FlowsBloc>();
          final triggersBloc = context.read<TriggersBloc>();
          await context.push('/flows/${flow.id}');
          flowsBloc.add(const FlowsLoadRequested());
          triggersBloc.add(const TriggersLoadRequested());
        },
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<FlowsBloc, FlowsState>(
        builder: (context, state) => switch (state) {
          FlowsLoading() => const AppLoadingIndicator(
            key: Key('flows.loading'),
          ),
          FlowsLoaded(flows: final fs) => _content(context, fs),
          FlowsMutating(flows: final fs) => _content(context, fs),
          FlowsMutationFailed(flows: final fs) => _content(context, fs),
          FlowsFailed() => const _FailedView(),
        },
      ),
    );
  }

  Widget _content(BuildContext context, List<fdom.Flow> all) {
    final q = _query;
    final filtered = q.isEmpty
        ? all
        : all
              .where((f) => f.name.toLowerCase().contains(q))
              .toList(growable: false);
    return SingleChildScrollView(
      key: const Key('template_flows.content'),
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp4,
        AppTokens.sp6,
        // fabClearance: la última fila debe poder quedar por encima del FAB
        // de crear que flota sobre esta página.
        AppTokens.fabClearance + context.safeBottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Sin flujos no hay nada que filtrar: el buscador solo aparece
          // cuando existe una lista que recortar.
          if (all.isNotEmpty) ...<Widget>[
            AppTextField(
              key: const Key('template_flows.search'),
              label: 'Buscar',
              hint: 'Nombre del flujo',
              controller: _search,
            ),
            const SizedBox(height: AppTokens.sp4),
          ],
          if (all.isEmpty)
            Text(
              'Este Asistente aún no tiene flujos.',
              key: const Key('flows.empty'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppTokens.text2,
              ),
            )
          else if (filtered.isEmpty)
            Text(
              'Sin resultados para "${_search.text.trim()}".',
              key: const Key('template_flows.no_results'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppTokens.text2,
              ),
            )
          else
            // El count de disparadores por flujo sale del TriggersBloc del
            // template (un solo GET); cada fila lo consume del mapa.
            BlocBuilder<TriggersBloc, TriggersState>(
              builder: (context, tState) => _FlowsCard(
                flows: filtered,
                triggerCounts: _triggerCounts(tState),
              ),
            ),
        ],
      ),
    );
  }

  /// Counts por flowId; null mientras el bloc de triggers no tiene snapshot
  /// (la fila omite esa parte del resumen en vez de mentir un 0).
  static Map<String, int>? _triggerCounts(TriggersState state) {
    if (state is! TriggersLoaded) return null;
    final counts = <String, int>{};
    for (final t in state.triggers) {
      counts[t.flowId] = (counts[t.flowId] ?? 0) + 1;
    }
    return counts;
  }
}

/// El listado como UNA card que apila las filas de flujos separadas por
/// divider hairline (idioma de los hubs y de las listas de bots/plantillas),
/// en lugar de una card suelta por item.
class _FlowsCard extends StatelessWidget {
  const _FlowsCard({required this.flows, required this.triggerCounts});

  final List<fdom.Flow> flows;

  /// Counts por flowId; null = aún sin snapshot (la fila omite el resumen).
  final Map<String, int>? triggerCounts;

  @override
  Widget build(BuildContext context) {
    final counts = triggerCounts;
    final rows = <Widget>[];
    for (var i = 0; i < flows.length; i++) {
      if (i > 0) {
        rows.add(
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
        );
      }
      final f = flows[i];
      rows.add(
        _FlowTile(
          flow: f,
          triggerCount: counts == null ? null : (counts[f.id] ?? 0),
        ),
      );
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

/// Fila de un flujo dentro de la card del listado: glifo + nombre con el
/// resumen (disparadores · enfriamiento · límite) como caption. El estado
/// habla solo cuando es excepcional: "Pausado" como pill; un flujo activo
/// no pinta nada — el default repetido por fila sería ruido. Las acciones
/// sobre el flujo (renombrar, pausar, eliminar) viven en su editor.
///
/// Toda la fila es tap-target hacia el editor; el InkWell propio da el
/// ripple (la card contenedora no es tappable).
class _FlowTile extends StatelessWidget {
  const _FlowTile({required this.flow, required this.triggerCount});

  final fdom.Flow flow;

  /// Disparadores del flujo; null = aún sin snapshot (se omite del resumen).
  final int? triggerCount;

  /// Apila el editor y, al volver, refresca lista y counts: el editor
  /// pudo renombrar, pausar o eliminar el flujo y sus disparadores.
  Future<void> _openEditor(BuildContext context) async {
    final flowsBloc = context.read<FlowsBloc>();
    final triggersBloc = context.read<TriggersBloc>();
    await context.push('/flows/${flow.id}');
    flowsBloc.add(const FlowsLoadRequested());
    triggersBloc.add(const TriggersLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final meta = _meta();
    return InkWell(
      key: Key('flows.row.${flow.id}'),
      // push apila el editor del flow; el back físico vuelve a la lista.
      onTap: () => _openEditor(context),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
        child: Row(
          children: <Widget>[
            const AppEntityIcon(icon: Icons.account_tree_outlined),
            const SizedBox(width: AppTokens.sp4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    flow.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTokens.text2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.sp2),
            if (!flow.isActive)
              AppPill.outline(
                key: Key('flows.row.${flow.id}.status_pill'),
                label: 'Pausado',
                dot: AppPillDot.paused,
              ),
            const Icon(Icons.chevron_right, color: AppTokens.text2),
          ],
        ),
      ),
    );
  }

  /// Resumen "3 disparadores · enfría 5 h · límite 10". Cada parte se omite
  /// cuando no aplica; sin disparadores se dice explícito (señal útil: un
  /// flujo sin disparadores nunca corre solo).
  String _meta() {
    final c = triggerCount;
    final parts = <String>[
      if (c != null)
        c == 0
            ? 'Sin disparadores'
            : (c == 1 ? '1 disparador' : '$c disparadores'),
      if (flow.cooldownMs > 0) 'enfría ${_cooldownLabel(flow.cooldownMs)}',
      if (flow.usageLimit > 0) 'límite ${flow.usageLimit}',
    ];
    return parts.join(' · ');
  }

  static String _cooldownLabel(int ms) {
    final s = ms ~/ 1000;
    if (s < 60) return '$s s';
    final m = s ~/ 60;
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    if (h < 24) return '$h h';
    return '${h ~/ 24} d';
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.sp6),
      child: Row(
        key: const Key('flows.failed'),
        children: <Widget>[
          Expanded(
            child: Text(
              'No pudimos cargar los flujos.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
            ),
          ),
          AppButton.text(
            label: 'Reintentar',
            onPressed: () =>
                context.read<FlowsBloc>().add(const FlowsLoadRequested()),
          ),
        ],
      ),
    );
  }
}
