import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../templates/domain/entities/template.dart';
import '../../../templates/presentation/bloc/templates_bloc.dart';

/// Selector de plantilla para arrancar la creación de un bot desde la tab
/// Bots. Consume el `TemplatesBloc` del scope; el cableado del provider y
/// el dispatch del primer load lo hace el router en `/bots/new`. Es
/// content-only: el Scaffold y el AppBar los aporta la ruta.
///
/// Al elegir una plantilla la navegación es `pushReplacement` a
/// `/templates/:templateId/bots/new?name=...`. El picker es transitorio:
/// una vez seleccionada, no agrega valor regresar a él — el back físico
/// del form vuelve al shell, no a esta lista intermedia.
class BotTemplatePickerPage extends StatelessWidget {
  const BotTemplatePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TemplatesBloc, TemplatesState>(
      builder: (context, state) => switch (state) {
        TemplatesInitial() || TemplatesLoading() => const _LoadingView(),
        TemplatesLoaded(items: final items) => _LoadedView(items: items),
        TemplatesFailed() => const _FailedView(),
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
  const _LoadedView({required this.items});

  final List<Template> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyView();
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _TemplateTile(template: items[i]),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('bot_template_picker.empty'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Text(
              'No tienes plantillas todavía.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Crea una desde la tab Plantillas para poder crear bots.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('bot_template_picker.error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'No pudimos cargar tus plantillas',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.read<TemplatesBloc>().add(
                const TemplatesLoadRequested(),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(_initial(template.name))),
      title: Text(template.name),
      subtitle: Text(_providerLabel(template.ai.provider)),
      onTap: () {
        // `encodeQueryComponent` (no `encodeFull`): el nombre va dentro
        // de un par clave=valor, así que `&` y `=` también deben
        // escaparse — encodeFull los preservaría y rompería el query.
        final name = Uri.encodeQueryComponent(template.name);
        context.pushReplacement(
          '/templates/${template.id}/bots/new?name=$name',
        );
      },
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
}
