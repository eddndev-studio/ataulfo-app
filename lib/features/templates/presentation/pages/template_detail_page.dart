import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/provider_badge.dart';
import '../../domain/entities/template.dart';
import '../../domain/entities/variable_def.dart';
import '../../domain/failures/templates_failure.dart';
import '../bloc/template_detail_bloc.dart';
import '../bloc/var_defs_bloc.dart';

/// Detalle de una Template (S03). Consume el `TemplateDetailBloc` del scope;
/// el cableado del provider y del ID lo hace el router en `/templates/:id`.
/// Es content-only: el Scaffold y el AppBar los aporta la ruta.
class TemplateDetailPage extends StatelessWidget {
  const TemplateDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TemplateDetailBloc, TemplateDetailState>(
      builder: (context, state) => switch (state) {
        TemplateDetailLoading() => const _LoadingView(),
        TemplateDetailLoaded(template: final tpl) => _LoadedView(template: tpl),
        TemplateDetailFailed(failure: final f) => _FailedView(failure: f),
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

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    final ai = template.ai;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.sp6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppAvatar(name: template.name, size: 64),
              const SizedBox(width: AppTokens.sp4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(template.name, style: textTheme.titleLarge),
                    const SizedBox(height: 2),
                    ProviderBadge(provider: ai.provider),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.sp6),
          Wrap(
            spacing: AppTokens.sp2,
            runSpacing: AppTokens.sp2,
            children: <Widget>[
              AppPill.outline(label: 'v${template.version}'),
              // IA on/off es estado de configuración, no error: primary
              // cuando está habilitada, neutral cuando no — danger queda
              // reservado para fallos reales (load errors, destructive).
              if (ai.enabled)
                const AppPill.primary(
                  label: 'IA habilitada',
                  dot: AppPillDot.active,
                )
              else
                const AppPill.neutral(
                  label: 'IA deshabilitada',
                  dot: AppPillDot.paused,
                ),
            ],
          ),
          const SizedBox(height: AppTokens.sp6),
          const _SectionTitle('Motor IA'),
          const SizedBox(height: AppTokens.sp3),
          _StatGrid(ai: ai),
          const SizedBox(height: AppTokens.sp6),
          const _SectionTitle('Prompt del sistema'),
          const SizedBox(height: AppTokens.sp3),
          if (ai.systemPrompt.isEmpty)
            Text(
              'Sin prompt definido',
              style: textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppTokens.text2,
              ),
            )
          else
            SelectableText(ai.systemPrompt, style: textTheme.bodyMedium),
          const SizedBox(height: AppTokens.sp6),
          const _SectionTitle('Variables'),
          const SizedBox(height: AppTokens.sp3),
          const _VarDefsSection(),
          const SizedBox(height: AppTokens.sp7),
          _EditButton(template: template),
          const SizedBox(height: AppTokens.sp3),
          _CreateBotButton(template: template),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(color: AppTokens.text2),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.ai});

  final AIConfig ai;

  @override
  Widget build(BuildContext context) {
    // 2×2 stats — la sección Motor IA cabe en una grilla compacta en
    // mobile sin scroll horizontal y deja respirar el system prompt
    // debajo. IntrinsicHeight iguala la altura de las dos cards de cada
    // fila cuando un modelo largo (p.ej. 'gemini-3.1-pro-preview')
    // estira una columna pero no la otra.
    return Column(
      children: <Widget>[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _StatTile(label: 'Modelo', value: ai.model),
              ),
              const SizedBox(width: AppTokens.cardGap),
              Expanded(
                child: _StatTile(
                  label: 'Temperatura',
                  value: ai.temperature.toStringAsFixed(1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.cardGap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _StatTile(
                  label: 'Razonamiento',
                  value: _thinkingLabel(ai.thinkingLevel),
                ),
              ),
              const SizedBox(width: AppTokens.cardGap),
              Expanded(
                child: _StatTile(
                  label: 'Mensajes de contexto',
                  value: ai.contextMessages.toString(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _thinkingLabel(ThinkingLevel t) => switch (t) {
    ThinkingLevel.low => 'Bajo',
    ThinkingLevel.medium => 'Medio',
    ThinkingLevel.high => 'Alto',
  };
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: AppTokens.sp4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: textTheme.labelSmall),
          const SizedBox(height: AppTokens.sp1),
          Text(value, style: textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _VarDefsSection extends StatelessWidget {
  const _VarDefsSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VarDefsBloc, VarDefsState>(
      builder: (context, state) => switch (state) {
        VarDefsLoading() => const Padding(
          key: Key('var_defs.loading'),
          padding: EdgeInsets.symmetric(vertical: AppTokens.sp2),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        VarDefsLoaded(defs: final defs) when defs.isEmpty => Text(
          'Esta plantilla aún no tiene variables.',
          key: const Key('var_defs.empty'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: AppTokens.text2,
          ),
        ),
        VarDefsLoaded(defs: final defs) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[for (final d in defs) _VarDefRow(def: d)],
        ),
        VarDefsFailed() => const _VarDefsFailedView(),
      },
    );
  }
}

class _VarDefRow extends StatelessWidget {
  const _VarDefRow({required this.def});

  final VariableDef def;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 180,
                // El placeholder de interpolación `{{name}}` es la forma en
                // que el operador referencia la variable desde el prompt;
                // mostrarla así es más útil que el name pelado.
                child: SelectableText(
                  '{{${def.name}}}',
                  style: t.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  def.defaultValue.isEmpty ? '—' : def.defaultValue,
                  style: t.bodyMedium?.copyWith(
                    color: def.defaultValue.isEmpty ? AppTokens.text2 : null,
                  ),
                ),
              ),
            ],
          ),
          if (def.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                def.description,
                style: t.bodySmall?.copyWith(color: AppTokens.text2),
              ),
            ),
        ],
      ),
    );
  }
}

class _VarDefsFailedView extends StatelessWidget {
  const _VarDefsFailedView();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('var_defs.failed'),
      children: <Widget>[
        const Expanded(
          child: Text(
            'No pudimos cargar las variables.',
            style: TextStyle(color: AppTokens.danger),
          ),
        ),
        AppButton.text(
          label: 'Reintentar',
          onPressed: () =>
              context.read<VarDefsBloc>().add(const VarDefsLoadRequested()),
        ),
      ],
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    return AppButton.tonal(
      key: const Key('template_detail.edit_button'),
      label: 'Editar plantilla',
      icon: Icons.edit_outlined,
      onPressed: () {
        // push apila el editor sobre el detalle; el back físico vuelve al
        // detalle (no sale de la app, no aplasta pila).
        context.push('/templates/${template.id}/edit');
      },
    );
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
      onPressed: () {
        // El nombre viaja como query param URL-encoded para que el form
        // pueda mostrar el chip de plantilla sin pedirla otra vez al
        // backend. push (no go) apila el form sobre el shell + detalle,
        // así el back físico de Android vuelve a este detalle.
        final name = Uri.encodeQueryComponent(template.name);
        context.push('/templates/${template.id}/bots/new?name=$name');
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
    return Center(
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
    );
  }
}
