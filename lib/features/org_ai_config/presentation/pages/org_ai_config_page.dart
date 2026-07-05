import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../ai_catalog/presentation/bloc/catalog_bloc.dart';
import '../../domain/failures/org_ai_config_failure.dart';
import '../bloc/org_ai_config_bloc.dart';
import '../widgets/host_selection_section.dart';
import '../widgets/org_defaults_section.dart';

/// Contenido de la configuración de IA a nivel ORGANIZACIÓN (ADMIN/OWNER):
/// proveedor por modelo + defaults de las plantillas nuevas. Content-only:
/// el router monta el Scaffold + AppBar planos (con [OrgAiConfigSaveAction]
/// como acción), la misma anatomía que el resto de pantallas de ajustes.
///
/// A diferencia del apply-inmediato del resto de la app, aquí el guardado es
/// explícito (dirty + Guardar): la pantalla edita VARIOS campos que viajan
/// juntos en UN solo PUT del contrato org/ai-config, así que las ediciones se
/// acumulan en `working` y se persisten de un golpe.
class OrgAiConfigPage extends StatelessWidget {
  const OrgAiConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OrgAiConfigBloc, OrgAiConfigState>(
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
        OrgAiConfigInitial() ||
        OrgAiConfigLoading() => const AppLoadingIndicator(),
        OrgAiConfigLoadFailed(:final failure) => _LoadError(failure: failure),
        OrgAiConfigLoaded() => _LoadedBody(state: state),
      },
    );
  }
}

/// Acción Guardar del AppBar; la monta el router junto al Scaffold. Habilitada
/// solo con cambios sin guardar; mientras el PUT viaja muestra el spinner del
/// propio botón.
class OrgAiConfigSaveAction extends StatelessWidget {
  const OrgAiConfigSaveAction({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrgAiConfigBloc, OrgAiConfigState>(
      builder: (context, state) {
        if (state is! OrgAiConfigLoaded) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: AppTokens.sp2),
          child: AppButton.text(
            key: const Key('org_ai.save'),
            label: 'Guardar',
            loading: state.saving,
            onPressed: state.dirty
                ? () => context.read<OrgAiConfigBloc>().add(
                    const OrgAiConfigSaveRequested(),
                  )
                : null,
          ),
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
    final textTheme = Theme.of(context).textTheme;
    // Las dos secciones necesitan el catálogo (hosts seleccionables + picker de
    // modelo de los defaults). Mientras el catálogo carga/falla, su estado manda.
    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, cat) => switch (cat) {
        CatalogInitial() || CatalogLoading() => const AppLoadingIndicator(),
        CatalogFailed() => const _CatalogError(),
        CatalogLoaded(:final catalog) => ListView(
          padding: EdgeInsets.fromLTRB(
            AppTokens.sp4,
            AppTokens.sp4,
            AppTokens.sp4,
            AppTokens.sp4 + context.safeBottomInset,
          ),
          children: <Widget>[
            // El guardado es explícito (a diferencia del apply-inmediato del
            // resto de la app): la línea lo hace legible antes de las cards.
            Text(
              'Los cambios se aplican al tocar Guardar.',
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp4),
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
    return ListView(
      padding: const EdgeInsets.all(AppTokens.sp4),
      children: <Widget>[
        if (forbidden)
          // Sin reintento: la autoridad es el 403 del backend y reintentar
          // no cambia el rol de quien mira.
          const AppErrorState(
            message: 'No tienes permiso para ver esta configuración.',
          )
        else
          AppErrorState(
            key: const Key('org_ai.retry'),
            message: 'No se pudo cargar la configuración de IA.',
            onRetry: () => context.read<OrgAiConfigBloc>().add(
              const OrgAiConfigLoadRequested(),
            ),
          ),
      ],
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppTokens.sp4),
    children: <Widget>[
      AppErrorState(
        key: const Key('org_ai.catalog_retry'),
        message: 'No se pudo cargar el catálogo de modelos.',
        onRetry: () =>
            context.read<CatalogBloc>().add(const CatalogLoadRequested()),
      ),
    ],
  );
}

String _saveErrorText(OrgAiConfigFailure f) => switch (f) {
  // El PUT valida la config completa (hosts por modelo + defaults): el copy
  // apunta a ambas secciones porque el backend no dice cuál campo falló.
  OrgAiConfigInvalidFailure() =>
    'Configuración inválida: revisa los valores por defecto o el host '
        'de algún modelo.',
  OrgAiConfigForbiddenFailure() => 'No tienes permiso para guardar.',
  OrgAiConfigNetworkFailure() => 'Sin conexión. Reintenta.',
  OrgAiConfigServerFailure() ||
  UnknownOrgAiConfigFailure() => 'No se pudo guardar. Reintenta.',
};
