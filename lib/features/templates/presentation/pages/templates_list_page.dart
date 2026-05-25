import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/template.dart';
import '../bloc/templates_bloc.dart';

/// Listado de Templates (S03). Consume el TemplatesBloc del scope; el
/// cableado del provider lo hace el route builder de `/home`. Es
/// content-only: el Scaffold y el AppBar los aporta el ShellPage, que
/// también orquesta el título dinámico por tab.
class TemplatesListPage extends StatelessWidget {
  const TemplatesListPage({super.key});

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
    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<TemplatesBloc>();
        bloc.add(const TemplatesRefreshRequested());
        // Esperamos a que el bloc deje el estado refreshing (o caiga a
        // Failed). Sin este await el RefreshIndicator quita el spinner
        // antes de tiempo y la animación parpadea.
        await bloc.stream.firstWhere(
          (s) =>
              (s is TemplatesLoaded && !s.isRefreshing) || s is TemplatesFailed,
        );
      },
      child: items.isEmpty
          ? const _EmptyView()
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _TemplateTile(template: items[i]),
            ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    // ListView de un solo hijo expandido = el RefreshIndicator sigue
    // funcionando porque el viewport es scrollable aunque la lista esté
    // vacía. Sin esto, AlwaysScrollableScrollPhysics no alcanza para que
    // el operador pueda jalar a refrescar sobre el empty state.
    return LayoutBuilder(
      builder: (context, c) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: const Center(
              key: Key('templates.empty'),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no tienes plantillas aquí',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('templates.error'),
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
      // push (no go): el detalle se APILA sobre el listado. Así el back
      // físico de Android y la flecha del AppBar de detalle vuelven al
      // shell. context.go() reemplaza la pila y deja al usuario sin back,
      // sacándolo de la app al primer tap del sistema.
      onTap: () => context.push('/templates/${template.id}'),
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
