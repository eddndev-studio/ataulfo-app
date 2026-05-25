import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/template.dart';
import '../../domain/failures/templates_failure.dart';
import '../bloc/template_detail_bloc.dart';

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
                label: Text(
                  ai.enabled ? 'IA habilitada' : 'IA deshabilitada',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionTitle('Motor IA'),
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
          _SectionTitle('Prompt del sistema'),
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
