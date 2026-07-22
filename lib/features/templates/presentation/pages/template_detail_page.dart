import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_section_link.dart';
import '../../../../core/design/widgets/provider_badge.dart';
import '../../../ai_catalog/presentation/widgets/thinking_label.dart';
import '../../../flows/presentation/bloc/flows_bloc.dart';
import '../../domain/entities/template.dart';
import '../../domain/failures/templates_failure.dart';
import '../bloc/template_detail_bloc.dart';
import '../bloc/var_defs_bloc.dart';
import '../widgets/template_detail_back_overlay.dart';
import '../widgets/template_detail_header.dart';
import '../widgets/template_rename_sheet.dart';
import '../widgets/template_assistant_card.dart';

/// Detalle de un Asistente sobre la entidad interna Template. Identidad en el
/// header de gradiente, el agente de plataforma como card hero, y las áreas que crecen
/// sin tope (flujos, variables, motor IA) como filas launcher hacia páginas
/// dedicadas — inline se volvían inusables con decenas de items. Consume el
/// `TemplateDetailBloc` del scope; FlowsBloc/VarDefsBloc alimentan counts y
/// captions de las filas. Content-only: el Scaffold lo aporta la ruta (sin
/// AppBar — el header aporta retorno y editar).
class TemplateDetailPage extends StatelessWidget {
  const TemplateDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TemplateDetailBloc, TemplateDetailState>(
      builder: (context, state) => switch (state) {
        TemplateDetailLoading() => const TemplateDetailBackOverlay(
          child: AppLoadingIndicator(),
        ),
        TemplateDetailLoaded(template: final tpl) => _LoadedView(template: tpl),
        // Mutación en vuelo / fallida: el detalle sigue pintado con el
        // snapshot (sin flash); el feedback fino lo da el sheet que mutó.
        TemplateDetailMutating(template: final tpl) => _LoadedView(
          template: tpl,
        ),
        TemplateDetailMutationFailed(template: final tpl) => _LoadedView(
          template: tpl,
        ),
        TemplateDetailFailed(failure: final f) => _FailedView(failure: f),
      },
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    final ai = template.ai;
    return SingleChildScrollView(
      // Sin padding aquí: el header es full-bleed y va pegado arriba. El
      // resto del contenido lleva su propio padding más abajo.
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TemplateDetailHeader(
            key: const Key('template_detail.header'),
            name: template.name,
            providerModelLabel:
                '${ProviderBadge.labelOf(ai.provider)} · ${ai.model}',
            version: template.version,
            aiEnabled: ai.enabled,
            onBack: () => Navigator.of(context).maybePop(),
            // Renombrar es una micro-tarea: sheet inferior, no pantalla.
            // El motor IA se edita en su propia página (launcher abajo).
            onEdit: () => TemplateRenameSheet.open(context, template),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTokens.sp6,
              AppTokens.sp6,
              AppTokens.sp6,
              AppTokens.sp6 + context.safeBottomInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TemplateAssistantCard(
                  templateId: template.id,
                  templateName: template.name,
                ),
                const SizedBox(height: AppTokens.sp6),
                _AssistantOverview(template: template),
                const SizedBox(height: AppTokens.sp6),
                _SectionLauncher(template: template),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantOverview extends StatelessWidget {
  const _AssistantOverview({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    final ai = template.ai;
    final channels = template.counts?.bots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Resumen', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppTokens.sp3),
        AppCard(
          child: Row(
            children: <Widget>[
              Expanded(
                child: _OverviewMetric(
                  icon: Icons.psychology_outlined,
                  label: ai.enabled
                      ? 'Comportamiento activo'
                      : 'Comportamiento pausado',
                  value: '${ProviderBadge.labelOf(ai.provider)} · ${ai.model}',
                ),
              ),
              const SizedBox(width: AppTokens.sp4),
              Expanded(
                child: _OverviewMetric(
                  icon: Icons.cable_outlined,
                  label: 'Canales',
                  value: channels == null
                      ? 'Consulta sus conexiones'
                      : '$channels ${channels == 1 ? 'conectado' : 'conectados'}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Icon(icon, color: AppTokens.primary),
      const SizedBox(height: AppTokens.sp2),
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 2),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppTokens.text2),
      ),
    ],
  );
}

/// Las áreas del producto se presentan con el vocabulario visible objetivo;
/// los paths /templates y /bots quedan como adaptadores internos temporales.
class _SectionLauncher extends StatelessWidget {
  const _SectionLauncher({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    final ai = template.ai;
    return Column(
      key: const Key('template_detail.card.sections'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitle('Comportamiento'),
        AppCard(
          child: Column(
            children: <Widget>[
              AppSectionLink(
                rowKey: const Key('template_detail.link.ai'),
                icon: Icons.psychology_outlined,
                title: 'Instrucciones y motor IA',
                caption:
                    '${ProviderBadge.labelOf(ai.provider)} · ${ai.model} · '
                    'temperatura ${ai.temperature.toStringAsFixed(1)} · '
                    'razonamiento '
                    '${thinkingLabel(ai.thinkingLevel).toLowerCase()}',
                onTap: () => context.push('/templates/${template.id}/ai'),
              ),
              const Divider(height: AppTokens.sp5, color: AppTokens.divider),
              BlocBuilder<VarDefsBloc, VarDefsState>(
                builder: (context, state) => AppSectionLink(
                  rowKey: const Key('template_detail.link.variables'),
                  icon: Icons.data_object,
                  title: 'Variables',
                  count: _varDefsCount(state),
                  caption: _varDefsCaption(state),
                  onTap: () =>
                      context.push('/templates/${template.id}/variables'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.sp5),
        const _SectionTitle('Recursos'),
        AppCard(
          child: Column(
            children: <Widget>[
              AppSectionLink(
                rowKey: const Key('template_detail.link.resources'),
                icon: Icons.library_books_outlined,
                title: 'Recursos disponibles',
                caption: 'Conocimiento y archivos permitidos',
                onTap: () => context.push(
                  Uri(
                    path: '/assistants/${template.id}/resources',
                    queryParameters: <String, String>{'name': template.name},
                  ).toString(),
                ),
              ),
              const Divider(height: AppTokens.sp5, color: AppTokens.divider),
              AppSectionLink(
                rowKey: const Key('template_detail.link.product_catalog'),
                icon: Icons.storefront_outlined,
                title: 'Catálogo de productos',
                caption: 'Productos y servicios que tus Asistentes ofrecen',
                onTap: () => context.push('/catalog/products'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.sp5),
        const _SectionTitle('Automatizaciones'),
        AppCard(
          child: BlocBuilder<FlowsBloc, FlowsState>(
            builder: (context, state) => AppSectionLink(
              rowKey: const Key('template_detail.link.flows'),
              icon: Icons.account_tree_outlined,
              title: 'Flujos',
              count: _flowsCount(state),
              caption: _flowsCaption(state),
              onTap: () => context.push('/templates/${template.id}/flows'),
            ),
          ),
        ),
        const SizedBox(height: AppTokens.sp5),
        const _SectionTitle('Canales'),
        AppCard(
          child: AppSectionLink(
            rowKey: const Key('template_detail.link.channels'),
            icon: Icons.cable_outlined,
            title: 'Canales conectados',
            count: template.counts?.bots,
            caption: template.counts?.bots == 0
                ? 'Pruébalo antes de conectarlo'
                : 'WhatsApp y futuras conexiones',
            onTap: () => context.push('/assistants/${template.id}/channels'),
          ),
        ),
        const SizedBox(height: AppTokens.sp5),
        const _SectionTitle('Probar'),
        AppCard(
          child: AppSectionLink(
            rowKey: const Key('template_detail.link.preview'),
            icon: Icons.play_circle_outline,
            title: 'Probar Asistente',
            caption: 'Conversa en un entorno seguro antes de publicarlo',
            onTap: () => context.push('/assistants/${template.id}/preview'),
          ),
        ),
      ],
    );
  }

  static int? _flowsCount(FlowsState state) => switch (state) {
    FlowsLoaded(flows: final f) => f.length,
    FlowsMutating(flows: final f) => f.length,
    FlowsMutationFailed(flows: final f) => f.length,
    _ => null,
  };

  static String? _flowsCaption(FlowsState state) {
    final flows = switch (state) {
      FlowsLoaded(flows: final f) => f,
      FlowsMutating(flows: final f) => f,
      FlowsMutationFailed(flows: final f) => f,
      _ => null,
    };
    if (flows == null) return null;
    if (flows.isEmpty) return 'Sin flujos aún';
    final active = flows.where((f) => f.isActive).length;
    final paused = flows.length - active;
    final a = active == 1 ? '1 activo' : '$active activos';
    final p = paused == 1 ? '1 pausado' : '$paused pausados';
    return '$a · $p';
  }

  static int? _varDefsCount(VarDefsState state) => switch (state) {
    VarDefsLoaded(defs: final d) => d.length,
    VarDefsMutating(defs: final d) => d.length,
    VarDefsMutationFailed(defs: final d) => d.length,
    _ => null,
  };

  static String? _varDefsCaption(VarDefsState state) {
    final defs = switch (state) {
      VarDefsLoaded(defs: final d) => d,
      VarDefsMutating(defs: final d) => d,
      VarDefsMutationFailed(defs: final d) => d,
      _ => null,
    };
    if (defs == null) return null;
    if (defs.isEmpty) return 'Sin variables aún';
    final names = defs.take(3).map((d) => '{{${d.name}}}').join(', ');
    return defs.length > 3 ? '$names…' : names;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppTokens.sp3),
    child: Text(label, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final TemplatesFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is TemplatesNotFoundFailure;
    final textTheme = Theme.of(context).textTheme;
    return TemplateDetailBackOverlay(
      child: Center(
        key: isNotFound
            ? const Key('template_detail.error.not_found')
            : const Key('template_detail.error.generic'),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.sp6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                isNotFound
                    ? 'Este Asistente ya no existe en tu organización'
                    : 'No pudimos cargar el detalle del Asistente',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: AppTokens.sp3),
              AppButton.tonal(
                label: 'Reintentar',
                onPressed: () => context.read<TemplateDetailBloc>().add(
                  const TemplateDetailLoadRequested(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
