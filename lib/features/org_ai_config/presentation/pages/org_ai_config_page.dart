import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../ai_catalog/presentation/bloc/catalog_bloc.dart';
import '../../domain/failures/org_ai_config_failure.dart';
import '../bloc/org_ai_config_bloc.dart';
import '../widgets/host_selection_section.dart';
import '../widgets/org_defaults_section.dart';

/// Pantalla de configuración de IA a nivel ORGANIZACIÓN (ADMIN/OWNER):
/// proveedor por modelo + defaults de las plantillas nuevas. Consume su propio
/// [OrgAiConfigBloc] y el [CatalogBloc] (para los hosts seleccionables y el
/// picker de modelo de los defaults). Provee su Scaffold para colgar la acción
/// Guardar, habilitada solo con cambios sin guardar.
class OrgAiConfigPage extends StatelessWidget {
  const OrgAiConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de IA'),
        actions: const <Widget>[_SaveAction()],
      ),
      body: BlocConsumer<OrgAiConfigBloc, OrgAiConfigState>(
        listenWhen: (prev, curr) =>
            curr is OrgAiConfigLoaded && curr.saveError != null,
        listener: (context, state) {
          if (state is OrgAiConfigLoaded && state.saveError != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(_saveErrorText(state.saveError!))),
              );
          }
        },
        builder: (context, state) => switch (state) {
          OrgAiConfigInitial() || OrgAiConfigLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          OrgAiConfigLoadFailed(:final failure) => _LoadError(failure: failure),
          OrgAiConfigLoaded() => _LoadedBody(state: state),
        },
      ),
    );
  }
}

class _SaveAction extends StatelessWidget {
  const _SaveAction();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrgAiConfigBloc, OrgAiConfigState>(
      builder: (context, state) {
        if (state is! OrgAiConfigLoaded) return const SizedBox.shrink();
        if (state.saving) {
          return const Padding(
            padding: EdgeInsets.only(right: AppTokens.sp3),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return TextButton(
          key: const Key('org_ai.save'),
          onPressed: state.dirty
              ? () => context.read<OrgAiConfigBloc>().add(
                  const OrgAiConfigSaveRequested(),
                )
              : null,
          child: const Text('Guardar'),
        );
      },
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.state});

  final OrgAiConfigLoaded state;

  @override
  Widget build(BuildContext context) {
    // Las dos secciones necesitan el catálogo (hosts seleccionables + picker de
    // modelo de los defaults). Mientras el catálogo carga/falla, su estado manda.
    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, cat) => switch (cat) {
        CatalogInitial() ||
        CatalogLoading() => const Center(child: CircularProgressIndicator()),
        CatalogFailed() => const _CatalogError(),
        CatalogLoaded(:final catalog) => ListView(
          padding: const EdgeInsets.all(AppTokens.sp4),
          children: <Widget>[
            AppCard(
              child: HostSelectionSection(
                catalog: catalog,
                config: state.working,
                enabled: !state.saving,
                onHostChanged: (model, host) => context
                    .read<OrgAiConfigBloc>()
                    .add(OrgAiConfigHostChanged(model: model, host: host)),
              ),
            ),
            const SizedBox(height: AppTokens.sp4),
            AppCard(
              child: OrgDefaultsSection(
                catalog: catalog,
                defaults: state.working.defaults,
                enabled: !state.saving,
                onChanged: (cfg) => context.read<OrgAiConfigBloc>().add(
                  OrgAiConfigDefaultsChanged(cfg),
                ),
              ),
            ),
          ],
        ),
      },
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.failure});

  final OrgAiConfigFailure failure;

  @override
  Widget build(BuildContext context) {
    final forbidden = failure is OrgAiConfigForbiddenFailure;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              forbidden
                  ? 'No tienes permiso para ver esta configuración.'
                  : 'No se pudo cargar la configuración de IA.',
              textAlign: TextAlign.center,
            ),
            if (!forbidden) ...<Widget>[
              const SizedBox(height: AppTokens.sp3),
              FilledButton(
                key: const Key('org_ai.retry'),
                onPressed: () => context.read<OrgAiConfigBloc>().add(
                  const OrgAiConfigLoadRequested(),
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppTokens.sp4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'No se pudo cargar el catálogo de modelos.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.sp3),
          FilledButton(
            key: const Key('org_ai.catalog_retry'),
            onPressed: () =>
                context.read<CatalogBloc>().add(const CatalogLoadRequested()),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

String _saveErrorText(OrgAiConfigFailure f) => switch (f) {
  OrgAiConfigInvalidFailure() =>
    'Configuración inválida: revisa el host de algún modelo.',
  OrgAiConfigForbiddenFailure() => 'No tienes permiso para guardar.',
  OrgAiConfigNetworkFailure() => 'Sin conexión. Reintenta.',
  OrgAiConfigServerFailure() ||
  UnknownOrgAiConfigFailure() => 'No se pudo guardar. Reintenta.',
};
