import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/provider_badge.dart';
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
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.sp4,
                vertical: AppTokens.sp4,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTokens.cardGap),
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
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(
              key: const Key('templates.empty'),
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.sp6),
                child: Text(
                  'Todavía no tienes plantillas aquí',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge,
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
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('templates.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No pudimos cargar tus plantillas',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<TemplatesBloc>().add(
                const TemplatesLoadRequested(),
              ),
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
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      // push (no go): el detalle se APILA sobre el listado. Así el back
      // físico de Android y la flecha del AppBar de detalle vuelven al
      // shell. context.go() reemplaza la pila y deja al usuario sin back,
      // sacándolo de la app al primer tap del sistema.
      onTap: () => context.push('/templates/${template.id}'),
      child: Row(
        children: <Widget>[
          AppAvatar(name: template.name),
          const SizedBox(width: AppTokens.sp4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(template.name, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                ProviderBadge(provider: template.ai.provider),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
