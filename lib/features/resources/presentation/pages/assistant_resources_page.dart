import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../domain/entities/resource_item.dart';
import '../bloc/assistant_resources_cubit.dart';

class AssistantResourcesPage extends StatelessWidget {
  const AssistantResourcesPage({super.key, required this.assistantName});

  final String assistantName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recursos disponibles')),
      body: BlocBuilder<AssistantResourcesCubit, AssistantResourcesState>(
        builder: (context, state) => switch (state) {
          AssistantResourcesLoading() => const _ResourcesSkeleton(),
          AssistantResourcesFailed(message: final message) => _Failed(
            message: message,
          ),
          AssistantResourcesLoaded() => _Loaded(
            assistantName: assistantName,
            state: state,
          ),
        },
      ),
    );
  }
}

class _ResourcesSkeleton extends StatelessWidget {
  const _ResourcesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.sp5),
      children: <Widget>[
        for (final height in <double>[132, 72, 72, 72]) ...<Widget>[
          Container(
            height: height,
            decoration: BoxDecoration(
              color: AppTokens.surface1,
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              border: Border.all(color: AppTokens.divider),
            ),
          ),
          const SizedBox(height: AppTokens.sp3),
        ],
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: AppTokens.text2,
            ),
            const SizedBox(height: AppTokens.sp3),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppTokens.sp4),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<AssistantResourcesCubit>().load(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.assistantName, required this.state});

  final String assistantName;
  final AssistantResourcesLoaded state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AssistantResourcesCubit>();
    final visible = state.scope == AssistantResourceScope.all
        ? state.library
              .where((item) => state.effectiveIds.contains(item.id))
              .toList()
        : state.library;
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp5,
          AppTokens.sp4,
          AppTokens.sp5,
          AppTokens.sp6 + context.safeBottomInset,
        ),
        children: <Widget>[
          Text(
            assistantName.isEmpty ? 'Biblioteca del Asistente' : assistantName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTokens.sp1),
          Text(
            'El conocimiento pertenece a la organización. Aquí sólo decides qué puede usar este Asistente.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp5),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Acceso', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppTokens.sp2),
                Material(
                  color: Colors.transparent,
                  child: RadioGroup<AssistantResourceScope>(
                    groupValue: state.scope,
                    onChanged: (value) {
                      if (!state.saving && value != null) cubit.setScope(value);
                    },
                    child: Column(
                      children: <Widget>[
                        RadioListTile<AssistantResourceScope>(
                          contentPadding: EdgeInsets.zero,
                          value: AssistantResourceScope.all,
                          enabled: !state.saving,
                          title: const Text('Toda la Biblioteca'),
                          subtitle: const Text(
                            'Recomendado: incluye automáticamente los recursos activos.',
                          ),
                        ),
                        RadioListTile<AssistantResourceScope>(
                          contentPadding: EdgeInsets.zero,
                          value: AssistantResourceScope.selected,
                          enabled: !state.saving,
                          title: const Text('Selección personalizada'),
                          subtitle: const Text(
                            'Muestra controles individuales sólo cuando los necesitas.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.notice != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp3),
            _Notice(message: state.notice!),
          ],
          if (state.needsReload) ...<Widget>[
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Recargar selección',
              onPressed: state.saving ? null : cubit.load,
            ),
          ],
          const SizedBox(height: AppTokens.sp5),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  state.scope == AssistantResourceScope.all
                      ? 'Disponibles ahora'
                      : 'Recursos de la organización',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${visible.length}',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppTokens.text2),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.sp3),
          if (visible.isEmpty)
            const _EmptyLibrary()
          else
            AppCard(
              child: Column(
                children: <Widget>[
                  for (
                    var index = 0;
                    index < visible.length;
                    index++
                  ) ...<Widget>[
                    if (index > 0)
                      const Divider(
                        height: AppTokens.sp4,
                        color: AppTokens.divider,
                      ),
                    _ResourceRow(
                      resource: visible[index],
                      selected: state.effectiveIds.contains(visible[index].id),
                      customizable:
                          state.scope == AssistantResourceScope.selected,
                      enabled: !state.saving && !state.needsReload,
                      onChanged: (selected) =>
                          cubit.setResource(visible[index], selected: selected),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppTokens.sp3),
    decoration: BoxDecoration(
      color: AppTokens.warning.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      border: Border.all(color: AppTokens.warning),
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.info_outline, color: AppTokens.warning),
        const SizedBox(width: AppTokens.sp2),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.resource,
    required this.selected,
    required this.customizable,
    required this.enabled,
    required this.onChanged,
  });

  final ResourceItem resource;
  final bool selected;
  final bool customizable;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final inherited = resource.sharedByDefault;
    return Row(
      key: Key('resources.item.${resource.id}'),
      children: <Widget>[
        Icon(_icon(resource.kind), color: AppTokens.text2),
        const SizedBox(width: AppTokens.sp3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                resource.name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                inherited
                    ? '${_label(resource.kind)} · incluido por la organización'
                    : _label(resource.kind),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTokens.text2),
              ),
            ],
          ),
        ),
        if (customizable)
          Switch.adaptive(
            key: Key('resources.toggle.${resource.id}'),
            value: inherited || selected,
            onChanged: enabled && !inherited ? onChanged : null,
          )
        else
          const Icon(Icons.check_circle_outline, color: AppTokens.success),
      ],
    );
  }

  static String _label(ResourceKind kind) => switch (kind) {
    ResourceKind.knowledgeDocument => 'Conocimiento',
    ResourceKind.file => 'Archivo enviable',
    ResourceKind.media => 'Medio',
    ResourceKind.product => 'Producto',
    ResourceKind.unknown => 'Recurso',
  };

  static IconData _icon(ResourceKind kind) => switch (kind) {
    ResourceKind.knowledgeDocument => Icons.article_outlined,
    ResourceKind.file => Icons.attach_file,
    ResourceKind.media => Icons.image_outlined,
    ResourceKind.product => Icons.inventory_2_outlined,
    ResourceKind.unknown => Icons.extension_outlined,
  };
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) => AppCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp5),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.library_add_outlined,
            size: 36,
            color: AppTokens.text2,
          ),
          const SizedBox(height: AppTokens.sp2),
          Text(
            'La Biblioteca todavía está vacía',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppTokens.sp1),
          Text(
            'Ataúlfo puede crear documentos; medios y productos se conservan en sus áreas actuales.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTokens.text2),
          ),
        ],
      ),
    ),
  );
}
