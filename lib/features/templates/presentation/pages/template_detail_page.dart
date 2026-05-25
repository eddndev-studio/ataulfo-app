import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    final ai = template.ai;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(radius: 32, child: Text(_initial(template.name))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(template.name, style: textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(_providerLabel(ai.provider)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(label: Text('v${template.version}')),
              Chip(
                avatar: Icon(
                  ai.enabled
                      ? Icons.psychology_outlined
                      : Icons.psychology_alt_outlined,
                  size: 18,
                ),
                label: Text(ai.enabled ? 'IA habilitada' : 'IA deshabilitada'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Motor IA'),
          const SizedBox(height: 8),
          _FieldRow(label: 'Modelo', value: ai.model),
          _FieldRow(
            label: 'Temperatura',
            value: ai.temperature.toStringAsFixed(1),
          ),
          _FieldRow(
            label: 'Razonamiento',
            value: _thinkingLabel(ai.thinkingLevel),
          ),
          _FieldRow(
            label: 'Mensajes de contexto',
            value: ai.contextMessages.toString(),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Prompt del sistema'),
          const SizedBox(height: 8),
          if (ai.systemPrompt.isEmpty)
            Text(
              'Sin prompt definido',
              style: textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            SelectableText(ai.systemPrompt, style: textTheme.bodyMedium),
          const SizedBox(height: 24),
          const _SectionTitle('Variables'),
          const SizedBox(height: 8),
          const _VarDefsSection(),
        ],
      ),
    );
  }

  static String _initial(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  static String _providerLabel(AIProvider p) => switch (p) {
    AIProvider.openai => 'OpenAI',
    AIProvider.gemini => 'Gemini',
    AIProvider.minimax => 'MiniMax',
    AIProvider.deepseek => 'DeepSeek',
  };

  static String _thinkingLabel(ThinkingLevel t) => switch (t) {
    ThinkingLevel.low => 'Bajo',
    ThinkingLevel.medium => 'Medio',
    ThinkingLevel.high => 'Alto',
  };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Text(
      text,
      style: t.textTheme.titleMedium?.copyWith(
        color: t.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 180, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
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
          padding: EdgeInsets.symmetric(vertical: 8),
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final t = Theme.of(context);
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
                  style: t.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  def.defaultValue.isEmpty ? '—' : def.defaultValue,
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: def.defaultValue.isEmpty
                        ? t.colorScheme.onSurfaceVariant
                        : null,
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
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
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
        Expanded(
          child: Text(
            'No pudimos cargar las variables.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(
          onPressed: () =>
              context.read<VarDefsBloc>().add(const VarDefsLoadRequested()),
          child: const Text('Reintentar'),
        ),
      ],
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final TemplatesFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is TemplatesNotFoundFailure;
    return Center(
      key: isNotFound
          ? const Key('template_detail.error.not_found')
          : const Key('template_detail.error.generic'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              isNotFound
                  ? 'Esta plantilla ya no existe en tu organización'
                  : 'No pudimos cargar el detalle de la plantilla',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.read<TemplateDetailBloc>().add(
                const TemplateDetailLoadRequested(),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
