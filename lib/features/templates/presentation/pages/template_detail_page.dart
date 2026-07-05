import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_section_link.dart';
import '../../../../core/design/widgets/provider_badge.dart';
import '../../../bots/presentation/widgets/bot_create_sheet.dart';
import '../../../flows/presentation/bloc/flows_bloc.dart';
import '../../domain/entities/template.dart';
import '../../domain/failures/templates_failure.dart';
import '../bloc/template_detail_bloc.dart';
import '../bloc/var_defs_bloc.dart';
import '../widgets/template_detail_header.dart';
import '../widgets/template_rename_sheet.dart';
import '../../../ai_catalog/presentation/widgets/thinking_label.dart';
import '../widgets/trainer_hero_card.dart';

/// Detalle de una Template (S03): el HUB de la plantilla. Identidad en el
/// header de gradiente, el Entrenador como card hero, y las áreas que crecen
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
        TemplateDetailLoading() => const _LoadingView(),
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

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const _BackOverlay(
    child: Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
      ),
    ),
  );
}

/// Superpone un retorno claro arriba a la izquierda en los estados sin header
/// (carga/error). La ruta ya no aporta AppBar; sin esto el operador quedaría
/// atrapado si la carga cuelga o la plantilla falla.
class _BackOverlay extends StatelessWidget {
  const _BackOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: child),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back, color: AppTokens.text1),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ],
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
                TrainerHeroCard(templateId: template.id),
                const SizedBox(height: AppTokens.sp6),
                _SectionLauncher(template: template),
                const SizedBox(height: AppTokens.sp6),
                _CreateBotButton(template: template),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Launcher de las áreas de la plantilla: una card con filas hacia las
/// páginas dedicadas. Cada fila resume su área (count + caption) para que
/// el hub informe de un vistazo sin cargar las listas completas en pantalla.
class _SectionLauncher extends StatelessWidget {
  const _SectionLauncher({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    final ai = template.ai;
    return AppCard(
      key: const Key('template_detail.card.sections'),
      child: Column(
        children: <Widget>[
          BlocBuilder<FlowsBloc, FlowsState>(
            builder: (context, state) => AppSectionLink(
              rowKey: const Key('template_detail.link.flows'),
              icon: Icons.account_tree_outlined,
              title: 'Flujos',
              count: _flowsCount(state),
              caption: _flowsCaption(state),
              onTap: () => context.push('/templates/${template.id}/flows'),
            ),
          ),
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
          BlocBuilder<VarDefsBloc, VarDefsState>(
            builder: (context, state) => AppSectionLink(
              rowKey: const Key('template_detail.link.variables'),
              icon: Icons.data_object,
              title: 'Variables',
              count: _varDefsCount(state),
              caption: _varDefsCaption(state),
              onTap: () => context.push('/templates/${template.id}/variables'),
            ),
          ),
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
          AppSectionLink(
            rowKey: const Key('template_detail.link.ai'),
            icon: Icons.psychology_outlined,
            title: 'Motor IA',
            caption:
                'Temperatura ${ai.temperature.toStringAsFixed(1)} · '
                'razonamiento ${thinkingLabel(ai.thinkingLevel).toLowerCase()}',
            onTap: () => context.push('/templates/${template.id}/ai'),
          ),
        ],
      ),
    );
  }

  /// Count visible para la fila; null mientras la sección no tiene snapshot
  /// (Loading/Failed) — la fila va sin pill.
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

class _CreateBotButton extends StatelessWidget {
  const _CreateBotButton({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    return AppButton.filled(
      key: const Key('template_detail.create_bot_button'),
      label: 'Crear bot',
      icon: Icons.smart_toy_outlined,
      fullWidth: true,
      onPressed: () async {
        // Abre la hoja de creación con esta plantilla ya elegida (salta el
        // paso de selección). Al crear, la hoja devuelve el bot y aquí se
        // empuja su detalle sobre el shell + este detalle, así el back
        // físico vuelve a esta plantilla.
        final bot = await BotCreateSheet.open(context, template: template);
        if (bot != null && context.mounted) {
          unawaited(context.push('/bots/${bot.id}'));
        }
      },
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final TemplatesFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is TemplatesNotFoundFailure;
    final textTheme = Theme.of(context).textTheme;
    return _BackOverlay(
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
                    ? 'Esta plantilla ya no existe en tu organización'
                    : 'No pudimos cargar el detalle de la plantilla',
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
