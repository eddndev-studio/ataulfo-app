import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_danger_zone.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_section_link.dart';
import '../../../triggers/domain/repositories/triggers_repository.dart';
import '../../../triggers/presentation/bloc/triggers_bloc.dart';
import '../../domain/entities/flow.dart' as fdom;
import '../../domain/failures/flows_failure.dart';
import '../bloc/flow_detail_bloc.dart';
import '../widgets/flow_steps_section.dart';

/// Hub del editor de un Flow (S11): página content-only cuyo cuerpo
/// principal ES la lista de pasos, con las áreas satélite (Disparadores,
/// Configuración) como filas launcher hacia sus subpáginas y la zona
/// peligrosa (eliminar) al fondo — la anatomía canónica de los hubs de
/// detalle (plantilla, bot). El AppBar lo aporta la ruta con el NOMBRE
/// del flujo y el menú ⋮ (renombrar, pausar/activar).
///
/// El header del cuerpo solo habla cuando algo es excepcional: la pill
/// "Pausado". Un flujo activo no pinta nada — el default calla.
class FlowDetailPage extends StatelessWidget {
  const FlowDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FlowDetailBloc, FlowDetailState>(
      listener: (context, state) {
        if (state is FlowDetailDeleted) {
          // El flujo ya no existe: de regreso a la lista. El fallback
          // cubre el deep-link sin pila debajo.
          context.canPop() ? context.pop() : context.go('/home');
          return;
        }
        // Fallo de una mutación de cabecera disparada desde el hub
        // (pausar/activar, eliminar). Con un sheet encima (renombrar) el
        // fallo se reporta inline ahí; el gate `isCurrent` evita duplicar.
        if (state is FlowDetailMutationFailed &&
            (ModalRoute.of(context)?.isCurrent ?? true)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'No pudimos aplicar el cambio al flujo. Inténtalo de nuevo.',
                ),
              ),
            );
        }
      },
      builder: (context, state) => switch (state) {
        FlowDetailLoading() => const AppLoadingIndicator(),
        FlowDetailLoaded(flow: final f) => _LoadedHub(flow: f),
        // Mientras una mutación de cabecera está en vuelo o falló, el hub
        // sigue visible con el flow del snapshot.
        FlowDetailMutating(flow: final f) => _LoadedHub(flow: f),
        FlowDetailMutationFailed(flow: final f) => _LoadedHub(flow: f),
        // Borrado consumado: no queda nada que editar; la vista se vacía
        // mientras el listener navega de regreso.
        FlowDetailDeleted() => const SizedBox.shrink(),
        FlowDetailFailed(failure: final f) => _FailedView(failure: f),
      },
    );
  }
}

/// Cuerpo Loaded del hub: los pasos como superficie principal, con la
/// identidad excepcional arriba y el footer de navegación + zona
/// peligrosa al fondo, todo en un solo scroll (lo arma FlowStepsSection).
///
/// Monta el `TriggersBloc` del count de la fila "Disparadores": un GET
/// template-scoped que se refresca al volver de la subpágina.
class _LoadedHub extends StatelessWidget {
  const _LoadedHub({required this.flow});

  final fdom.Flow flow;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TriggersBloc>(
      create: (ctx) => TriggersBloc(
        repo: ctx.read<TriggersRepository>(),
        templateId: flow.templateId,
      )..add(const TriggersLoadRequested()),
      child: FlowStepsSection(
        header: flow.isActive
            ? null
            : const Align(
                alignment: Alignment.centerLeft,
                child: AppPill.neutral(
                  label: 'Pausado',
                  dot: AppPillDot.paused,
                ),
              ),
        footer: _HubFooter(flow: flow),
      ),
    );
  }
}

/// Footer del hub: la card de launchers hacia las subpáginas y la zona
/// peligrosa. Al volver de una subpágina se refrescan la cabecera (la
/// configuración sube la `version` del CAS) y el count de disparadores —
/// conservando los snapshots visibles (nunca Loading).
class _HubFooter extends StatelessWidget {
  const _HubFooter({required this.flow});

  final fdom.Flow flow;

  Future<void> _openSubpage(BuildContext context, String segment) async {
    final detail = context.read<FlowDetailBloc>();
    final triggers = context.read<TriggersBloc>();
    await context.push('/flows/${flow.id}/$segment');
    detail.add(const FlowDetailRefreshRequested());
    triggers.add(const TriggersLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppCard(
          child: Column(
            children: <Widget>[
              BlocBuilder<TriggersBloc, TriggersState>(
                builder: (context, state) => AppSectionLink(
                  rowKey: const Key('flow_detail.link.triggers'),
                  icon: Icons.bolt_outlined,
                  title: 'Disparadores',
                  count: _triggersCount(state),
                  caption: 'Palabras clave y etiquetas que lanzan este flujo',
                  onTap: () => _openSubpage(context, 'triggers'),
                ),
              ),
              const Divider(height: AppTokens.sp5, color: AppTokens.divider),
              AppSectionLink(
                rowKey: const Key('flow_detail.link.settings'),
                icon: Icons.tune,
                title: 'Configuración',
                caption: 'Enfriamiento, límite de usos y exclusiones',
                onTap: () => _openSubpage(context, 'settings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.sp6),
        AppDangerZone(
          caption:
              'Eliminar el flujo borra también sus pasos y disparadores. '
              'Esta acción no se puede deshacer.',
          actions: <Widget>[
            AppButton.danger(
              key: const Key('flow_detail.danger.delete'),
              label: 'Eliminar flujo',
              fullWidth: true,
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ],
    );
  }

  /// Disparadores DE ESTE flujo (el GET es template-scoped); null mientras
  /// no hay snapshot — la fila va sin pill en vez de mentir un 0.
  int? _triggersCount(TriggersState state) {
    final triggers = switch (state) {
      TriggersLoaded(triggers: final ts) => ts,
      TriggersMutating(triggers: final ts) => ts,
      TriggersMutationFailed(triggers: final ts) => ts,
      _ => null,
    };
    if (triggers == null) return null;
    return triggers.where((t) => t.flowId == flow.id).length;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bloc = context.read<FlowDetailBloc>();
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Eliminar flujo',
      message:
          '¿Eliminar el flujo "${flow.name}"? Se borrarán también sus pasos '
          'y disparadores. Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      confirmKey: const Key('flow_detail.delete_confirm'),
    );
    if (confirmed) {
      bloc.add(const FlowDetailDeleteRequested());
    }
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final FlowsFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is FlowsNotFoundFailure;
    // NotFound es terminal: recargar no lo revive, así que no hay reintento.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp5),
        child: AppErrorState(
          key: isNotFound
              ? const Key('flow_detail.error.not_found')
              : const Key('flow_detail.error.generic'),
          message: isNotFound
              ? 'Este flujo ya no existe en tu organización'
              : 'No pudimos cargar el detalle del flujo',
          onRetry: isNotFound
              ? null
              : () => context.read<FlowDetailBloc>().add(
                  const FlowDetailLoadRequested(),
                ),
        ),
      ),
    );
  }
}
