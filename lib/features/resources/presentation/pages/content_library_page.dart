import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_section_link.dart';
import '../../../templates/domain/entities/template.dart';
import '../../../templates/presentation/bloc/templates_bloc.dart';

/// Hub organizacional para activos reutilizables.
///
/// Medios y productos pertenecen a la organización. El workspace, en cambio,
/// pertenece a un Asistente concreto, por lo que nunca abre sin elegir antes
/// ese contexto.
class ContentLibraryPage extends StatelessWidget {
  const ContentLibraryPage({super.key, required this.showWorkspaces});

  final bool showWorkspaces;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp5,
        AppTokens.sp5,
        AppTokens.sp5,
        AppTokens.sp7 + context.safeBottomInset,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppTokens.maxContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Activos de la organización',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTokens.sp2),
              Text(
                'Administra aquí el contenido que se reutiliza en canales y '
                'Asistentes.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              ),
              const SizedBox(height: AppTokens.sp4),
              AppCard(
                key: const Key('library.organization_assets'),
                child: Column(
                  children: <Widget>[
                    AppSectionLink(
                      rowKey: const Key('library.media'),
                      icon: Icons.perm_media_outlined,
                      title: 'Archivos y medios',
                      caption: 'Imágenes, audio, video y documentos',
                      onTap: () => context.push('/media'),
                    ),
                    const Divider(
                      height: AppTokens.sp5,
                      color: AppTokens.divider,
                    ),
                    AppSectionLink(
                      rowKey: const Key('library.products'),
                      icon: Icons.inventory_2_outlined,
                      title: 'Productos y catálogo',
                      caption: 'Oferta comercial de la organización',
                      onTap: () => context.push('/catalog/products'),
                    ),
                  ],
                ),
              ),
              if (showWorkspaces) ...<Widget>[
                const SizedBox(height: AppTokens.sp7),
                Text(
                  'Workspaces por Asistente',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.sp2),
                Text(
                  'Elige el Asistente cuyo conocimiento del negocio quieres '
                  'administrar.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
                ),
                const SizedBox(height: AppTokens.sp4),
                const _WorkspaceList(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceList extends StatelessWidget {
  const _WorkspaceList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TemplatesBloc, TemplatesState>(
      builder: (context, state) => switch (state) {
        TemplatesInitial() || TemplatesLoading() => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppTokens.sp6),
          child: AppLoadingIndicator(label: 'Cargando Asistentes…'),
        ),
        TemplatesFailed() => AppErrorState(
          key: const Key('library.workspaces.error'),
          message: 'No se pudieron cargar los Asistentes',
          description: 'Revisa tu conexión o intenta nuevamente.',
          onRetry: () =>
              context.read<TemplatesBloc>().add(const TemplatesLoadRequested()),
        ),
        TemplatesLoaded(items: final items) =>
          items.isEmpty
              ? const AppEmptyState(
                  key: Key('library.workspaces.empty'),
                  icon: Icons.support_agent_outlined,
                  title: 'Aún no hay Asistentes',
                  description:
                      'Crea un Asistente antes de preparar su workspace.',
                )
              : _WorkspaceCard(templates: items),
      },
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({required this.templates});

  final List<Template> templates;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < templates.length; i++) {
      final template = templates[i];
      if (i > 0) {
        rows.add(
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
        );
      }
      rows.add(
        AppSectionLink(
          rowKey: Key('library.workspace.${template.id}'),
          icon: Icons.support_agent_outlined,
          title: template.name,
          caption: 'Documentos y conocimiento de este Asistente',
          onTap: () => context.push(
            '/assistants/${Uri.encodeComponent(template.id)}/workspace',
          ),
        ),
      );
    }
    return AppCard(
      key: const Key('library.workspaces'),
      child: Column(children: rows),
    );
  }
}
